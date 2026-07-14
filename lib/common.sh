#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# ARQUIVO.......: lib/common.sh
# NOME..........: Biblioteca comum de funções seguras
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Centralizar funções pequenas e reutilizáveis para módulos e utilitários do
# projeto. A biblioteca padroniza mensagens, validações, permissões, backups,
# logs, detecção de sistema e execução segura como usuário real.
#
# FLUXO DE USO
#
# 1. O módulo carrega esta biblioteca com source.
# 2. A proteção KALI_SETUP_COMMON_LOADED evita carregamento duplicado.
# 3. As funções ficam disponíveis para o script chamador.
# 4. Nenhuma alteração no sistema é executada apenas por carregar o arquivo.
#
# Esta biblioteca concentra funções pequenas e reutilizáveis para módulos e
# utilitários do projeto. Ela foi desenhada para ser carregada com source.
#
# REGRAS IMPORTANTES
#
# - Não executa alterações no sistema ao ser carregada.
# - Não lê, imprime ou armazena secrets.
# - Não usa eval.
# - Não chama exit no corpo principal do arquivo.
# - Protege contra carregamento duplo.
# - Retorna códigos de erro para que o script chamador decida como encerrar.
###############################################################################

if [[ -n "${KALI_SETUP_COMMON_LOADED:-}" ]]; then
    return 0 2>/dev/null
    exit 0
fi

readonly KALI_SETUP_COMMON_LOADED=1


###############################################################################
# CORES E MENSAGENS
###############################################################################

KALI_SETUP_RED=''
KALI_SETUP_GREEN=''
KALI_SETUP_YELLOW=''
KALI_SETUP_BLUE=''
KALI_SETUP_NC=''

if [[ -t 1 ]]; then
    if [[ -z "${NO_COLOR:-}" ]]; then
        KALI_SETUP_RED='\033[0;31m'
        KALI_SETUP_GREEN='\033[0;32m'
        KALI_SETUP_YELLOW='\033[1;33m'
        KALI_SETUP_BLUE='\033[0;34m'
        KALI_SETUP_NC='\033[0m'
    fi
fi

info() {
    printf '%b[INFO]%b %s\n' "$KALI_SETUP_BLUE" "$KALI_SETUP_NC" "$*"
}

success() {
    printf '%b[ OK ]%b %s\n' "$KALI_SETUP_GREEN" "$KALI_SETUP_NC" "$*"
}

warning() {
    printf '%b[WARN]%b %s\n' "$KALI_SETUP_YELLOW" "$KALI_SETUP_NC" "$*"
}

error() {
    printf '%b[ERRO]%b %s\n' "$KALI_SETUP_RED" "$KALI_SETUP_NC" "$*" >&2
}

die() {
    error "$*"
    return 1
}


###############################################################################
# TRATAMENTO PADRONIZADO DE ERROS
###############################################################################

kali_setup_handle_error() {
    local codigo_saida="$?"
    local comando_falhou="${BASH_COMMAND}"
    local linha_aproximada="${BASH_LINENO[0]:-${LINENO}}"

    printf '\n' >&2
    error "O script encontrou um erro."
    error "Comando executado: ${comando_falhou}"
    error "Linha aproximada: ${linha_aproximada}"
    error "Código de saída: ${codigo_saida}"
    printf '\n' >&2

    return "$codigo_saida"
}


###############################################################################
# VALIDAÇÕES DE PRIVILÉGIO E COMANDOS
###############################################################################

require_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        return 0
    fi

    die "Esta ação precisa ser executada com privilégios administrativos."
}

require_command() {
    local comando="$1"

    if command -v "$comando" >/dev/null 2>&1; then
        return 0
    fi

    die "Comando obrigatório não encontrado: ${comando}"
}

require_commands() {
    local comando=''

    for comando in "$@"; do
        require_command "$comando"
    done
}


###############################################################################
# USUÁRIO REAL E HOME
###############################################################################

get_real_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        printf '%s\n' "$SUDO_USER"
        return 0
    fi

    if [[ -n "${USER:-}" ]]; then
        printf '%s\n' "$USER"
        return 0
    fi

    id -un
}

get_user_home() {
    local usuario="$1"
    local entrada_passwd=''
    local nome=''
    local senha=''
    local uid=''
    local gid=''
    local gecos=''
    local home=''
    local shell=''

    if entrada_passwd="$(getent passwd "$usuario")"; then
        IFS=':' read -r nome senha uid gid gecos home shell <<< "$entrada_passwd"
        if [[ -n "$home" ]]; then
            printf '%s\n' "$home"
            return 0
        fi
    fi

    die "Não foi possível obter o home real de ${usuario}."
}


###############################################################################
# VALIDAÇÕES DE ARQUIVOS
###############################################################################

validate_not_symlink() {
    local caminho="$1"

    if [[ -L "$caminho" ]]; then
        die "Link simbólico recusado: ${caminho}"
        return 1
    fi

    return 0
}

validate_regular_file() {
    local caminho="$1"

    validate_not_symlink "$caminho" || return 1

    if [[ -f "$caminho" ]]; then
        return 0
    fi

    die "Arquivo regular não encontrado: ${caminho}"
}

validate_file_owner() {
    local caminho="$1"
    local dono_esperado="$2"
    local grupo_esperado="$3"
    local dono_atual=''
    local grupo_atual=''

    dono_atual="$(stat -c '%U' "$caminho")"
    grupo_atual="$(stat -c '%G' "$caminho")"

    if [[ "$dono_atual" != "$dono_esperado" ]]; then
        die "Proprietário inválido em ${caminho}: ${dono_atual}"
        return 1
    fi

    if [[ "$grupo_atual" != "$grupo_esperado" ]]; then
        die "Grupo inválido em ${caminho}: ${grupo_atual}"
        return 1
    fi

    return 0
}

validate_file_mode() {
    local caminho="$1"
    local modo_esperado="$2"
    local modo_atual=''

    modo_atual="$(stat -c '%a' "$caminho")"

    if [[ "$modo_atual" == "$modo_esperado" ]]; then
        return 0
    fi

    die "Permissão inválida em ${caminho}: ${modo_atual}"
}


###############################################################################
# DIRETÓRIOS E SAÍDA VISUAL
###############################################################################

ensure_directory() {
    local diretorio="$1"
    local modo="$2"
    local dono="${3:-}"
    local grupo="${4:-}"

    validate_not_symlink "$diretorio"

    if [[ -e "$diretorio" ]]; then
        if [[ ! -d "$diretorio" ]]; then
            die "O caminho existe, mas não é diretório: ${diretorio}"
            return 1
        fi
    else
        mkdir -p -- "$diretorio"
    fi

    chmod "$modo" "$diretorio"

    if [[ -n "$dono" ]]; then
        if [[ -n "$grupo" ]]; then
            chown "${dono}:${grupo}" "$diretorio"
        fi
    fi
}

print_section() {
    local titulo="$1"

    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' "$titulo"
    printf '%s\n' '============================================================'
    printf '\n'
}

print_summary_line() {
    local rotulo="$1"
    local valor="$2"

    printf '%-23s: %s\n' "$rotulo" "$valor"
}


###############################################################################
# SISTEMA, ARQUITETURA E APT
###############################################################################

detect_architecture() {
    uname -m
}

detect_kali_from_file() {
    local os_release="$1"

    # Esta validação é somente de leitura. Diferentemente de caminhos que o
    # projeto pode modificar, os-release pode ser um link simbólico legítimo.
    if [[ ! -f "$os_release" ]]; then
        die "Arquivo os-release regular não encontrado: ${os_release}"
        return 1
    fi

    if [[ ! -r "$os_release" ]]; then
        die "Arquivo os-release não está legível: ${os_release}"
        return 1
    fi

    if grep -q \
        -e '^ID=kali$' \
        -e '^ID="kali"$' \
        -e "^ID='kali'$" \
        "$os_release"; then
        return 0
    fi

    die "Sistema recusado: este módulo foi desenhado para Kali Linux."
}

detect_kali() {
    local os_release='/etc/os-release'

    # O padrão os-release dá prioridade a /etc/os-release e permite que ele
    # seja um link para o arquivo fornecido pelo sistema em /usr/lib.
    # Um link quebrado em /etc deve falhar em vez de ocultar o problema usando
    # silenciosamente o fallback.
    if [[ ! -e "$os_release" && ! -L "$os_release" ]]; then
        os_release='/usr/lib/os-release'
    fi

    detect_kali_from_file "$os_release"
}

command_exists() {
    local comando="$1"

    command -v "$comando" >/dev/null 2>&1
}

apt_package_exists() {
    local pacote="$1"

    apt-cache show "$pacote" >/dev/null 2>&1
}

apt_package_installed() {
    local pacote="$1"

    dpkg-query -W -f='${Status}\n' "$pacote" 2>/dev/null | grep -q '^install ok installed$'
}

install_apt_packages() {
    local pacote=''

    require_root
    require_commands apt-get apt-cache dpkg-query

    for pacote in "$@"; do
        if apt_package_installed "$pacote"; then
            success "Pacote já instalado: ${pacote}"
        else
            if apt_package_exists "$pacote"; then
                info "Instalando pacote por apt: ${pacote}"
                apt-get install -y -- "$pacote"
            else
                warning "Pacote não encontrado no apt: ${pacote}"
            fi
        fi
    done
}


###############################################################################
# USUÁRIO, PATH, BACKUP E LOG
###############################################################################

run_as_real_user() {
    local usuario="$1"

    shift

    if [[ -z "$usuario" ]]; then
        die "Usuário real vazio ao tentar executar comando."
        return 1
    fi

    sudo -u "$usuario" -- "$@"
}

ensure_path_entry() {
    local arquivo="$1"
    local entrada="$2"
    local marcador="# KALI SETUP PATH: ${entrada}"

    validate_not_symlink "$arquivo"

    if [[ -e "$arquivo" ]]; then
        if [[ ! -f "$arquivo" ]]; then
            die "Arquivo de shell inválido: ${arquivo}"
            return 1
        fi
    else
        : > "$arquivo"
    fi

    if grep -Fq "$marcador" "$arquivo"; then
        return 0
    fi

    printf '\n%s\n' "$marcador" >> "$arquivo"
    printf 'case ":$PATH:" in\n' >> "$arquivo"
    printf '    *":%s:"*) ;;\n' "$entrada" >> "$arquivo"
    printf '    *) PATH="%s:$PATH" ;;\n' "$entrada" >> "$arquivo"
    printf 'esac\n' >> "$arquivo"
    printf 'export PATH\n' >> "$arquivo"
}

backup_file() {
    local arquivo="$1"
    local destino_dir="$2"
    local base=''
    local destino=''

    validate_regular_file "$arquivo"
    ensure_directory "$destino_dir" '700'

    base="$(basename -- "$arquivo")"
    destino="${destino_dir}/${base}.$(date +%Y%m%d-%H%M%S).bak"

    cp --preserve=mode,ownership,timestamps -- "$arquivo" "$destino"
    printf '%s\n' "$destino"
}

confirm_action() {
    local pergunta="$1"
    local resposta=''

    printf '%s [s/N]: ' "$pergunta"

    if read -r resposta; then
        case "$resposta" in
            s|S|sim|SIM)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    fi

    return 1
}

start_log() {
    local usuario="$1"
    local modulo="$2"
    local home=''
    local log_dir=''
    local log_file=''

    home="$(get_user_home "$usuario")"
    log_dir="${home}/.local/state/kali-setup/logs"
    ensure_directory "$log_dir" '700' "$usuario" "$usuario"

    log_file="${log_dir}/${modulo}-$(date +%Y%m%d-%H%M%S).log"
    : > "$log_file"
    chmod 600 "$log_file"
    chown "${usuario}:${usuario}" "$log_file"

    printf '%s\n' "$log_file"
}


###############################################################################
# VALIDAÇÕES DE ORIGEM E BINÁRIOS
###############################################################################

validate_url_domain() {
    local url="$1"
    local dominio="$2"

    case "$url" in
        https://"${dominio}"/*|https://"${dominio}")
            return 0
            ;;
        *)
            die "URL fora do domínio permitido: ${url}"
            ;;
    esac
}

validate_git_repository() {
    local url="$1"

    case "$url" in
        https://github.com/*|https://gitlab.com/*|https://gitlab.com/*)
            return 0
            ;;
        *)
            die "Repositório Git não permitido sem validação adicional: ${url}"
            ;;
    esac
}

validate_binary() {
    local comando="$1"

    if command_exists "$comando"; then
        success "Binário encontrado: ${comando}"
        return 0
    fi

    warning "Binário ausente: ${comando}"
    return 1
}
