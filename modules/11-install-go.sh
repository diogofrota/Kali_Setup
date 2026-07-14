#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 11
# NOME..........: Instalação de Go e ferramentas Go
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Instalar o runtime Go e ferramentas escritas em Go, priorizando instalação no
# home do usuário real em ~/go/bin para evitar misturar binários de pentest com
# arquivos de sistema.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida que o sistema é Kali Linux.
# 3. Cria ~/go e ~/go/bin com dono e permissões corretas.
# 4. Instala golang-go via APT quando Go ainda não existe.
# 5. Lê config/tools-go.txt.
# 6. Instala automaticamente todas as ferramentas via Go ou APT.
# 7. Mostra no final o que foi instalado e quais itens falharam.
#
# RISCOS CONTROLADOS
#
# Algumas ferramentas têm nomes que podem conflitar com outros comandos, como
# httpx. Por isso a validação de ferramentas Go usa o caminho esperado
# ~/go/bin/<comando>, evitando falsos positivos no PATH.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='11-install-go'
NEXT_MODULE='12-install-rust.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/tools-go.txt"

# shellcheck source=../lib/common.sh
source "${PROJECT_ROOT}/lib/common.sh"

trap 'kali_setup_handle_error; exit $?' ERR

INSTALLED=0
EXISTING=0
SKIPPED=0
FAILED=0
declare -a INSTALLED_ITEMS=()
declare -a FAILED_ITEMS=()
LOG_FILE=''
REAL_USER=''
REAL_HOME=''
ARCHITECTURE=''

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 11' \
        '                   Go Tools' \
        '============================================================'
}

record_installed() {
    local item="$1"

    INSTALLED=$((INSTALLED + 1))
    INSTALLED_ITEMS+=("$item")
    success "Instalado: ${item}"
}

record_failure() {
    local item="$1"

    FAILED=$((FAILED + 1))
    FAILED_ITEMS+=("$item")
    error "Falha ao instalar ${item}. O módulo continuará com os próximos itens."
}

print_result_list() {
    local titulo="$1"
    local item=''

    shift
    printf '\n%s\n' "$titulo"

    if [[ "$#" -eq 0 ]]; then
        printf '  - Nenhum.\n'
        return 0
    fi

    for item in "$@"; do
        printf '  - %s\n' "$item"
    done
}

prepare_go_workspace() {
    # mkdir -p executado como root pode criar o diretório pai com dono errado.
    # Preparar cada nível separadamente também repara instalações parciais.
    ensure_directory "${REAL_HOME}/go" '700' "$REAL_USER" "$REAL_USER"
    ensure_directory "${REAL_HOME}/go/bin" '700' "$REAL_USER" "$REAL_USER"
}

ensure_go_runtime() {
    if command_exists go; then
        success "Go já está instalado."
        EXISTING=$((EXISTING + 1))
        return 0
    fi

    if apt_package_exists golang-go; then
        if apt-get install -y -- golang-go; then
            record_installed 'golang-go (APT/runtime)'
        else
            record_failure 'golang-go (APT/runtime)'
        fi
    else
        record_failure 'golang-go (pacote APT ausente)'
    fi
}

install_go_tool() {
    local nome="$1"
    local prioridade="$2"
    local origem="$3"
    local validacao="$4"
    local comando="${validacao%% *}"
    local caminho_binario="${REAL_HOME}/go/bin/${comando}"

    if [[ -x "$caminho_binario" ]]; then
        EXISTING=$((EXISTING + 1))
        success "Binário Go já existe: ${caminho_binario}"
        return 0
    fi

    case "$prioridade" in
        CORE|RECOMMENDED|OPTIONAL)
            ;;
        *)
            warning "Prioridade desconhecida para ${nome}: ${prioridade}. Item ignorado."
            SKIPPED=$((SKIPPED + 1))
            return 0
            ;;
    esac

    if ! command_exists go; then
        record_failure "${nome} (runtime Go ausente)"
        return 0
    fi

    info "Instalando ${nome} com go install a partir de ${origem}"
    if run_as_real_user "$REAL_USER" env \
        HOME="$REAL_HOME" \
        GOPATH="${REAL_HOME}/go" \
        GOBIN="${REAL_HOME}/go/bin" \
        go install "$origem"; then
        if [[ -x "$caminho_binario" ]]; then
            record_installed "${nome} (Go: ${origem})"
        else
            record_failure "${nome} (go install não criou ${caminho_binario})"
        fi
    else
        record_failure "${nome} (Go: ${origem})"
    fi
}

install_apt_tool() {
    local nome="$1"
    local prioridade="$2"
    local pacote="$3"

    case "$prioridade" in
        CORE|RECOMMENDED|OPTIONAL)
            ;;
        *)
            warning "Prioridade desconhecida para ${nome}: ${prioridade}. Item ignorado."
            SKIPPED=$((SKIPPED + 1))
            return 0
            ;;
    esac

    if apt_package_installed "$pacote"; then
        EXISTING=$((EXISTING + 1))
        success "Pacote já instalado: ${pacote}"
    elif apt_package_exists "$pacote"; then
        if apt-get install -y -- "$pacote"; then
            record_installed "${nome} (APT: ${pacote})"
        else
            record_failure "${nome} (APT: ${pacote})"
        fi
    else
        record_failure "${nome} (pacote APT ausente: ${pacote})"
    fi
}

process_go_inventory() {
    local linha=''
    local nome=''
    local categoria=''
    local prioridade=''
    local metodo=''
    local origem=''
    local validacao=''
    local arquitetura=''

    # Mantém o inventário separado da entrada interativa do terminal.
    while IFS= read -r -u 9 linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi
        if [[ "$linha" == \#* ]]; then
            continue
        fi

        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        case "$metodo" in
            go)
                install_go_tool "$nome" "$prioridade" "$origem" "$validacao"
                ;;
            apt)
                install_apt_tool "$nome" "$prioridade" "$origem"
                ;;
            *)
                warning "Método desconhecido para ${nome}: ${metodo}. Item ignorado."
                SKIPPED=$((SKIPPED + 1))
                ;;
        esac
    done 9< "$CONFIG_FILE"
}

main() {
    print_banner
    require_root
    require_commands apt-get apt-cache dpkg-query getent sudo mkdir chmod chown env
    detect_kali
    ARCHITECTURE="$(detect_architecture)"
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    validate_regular_file "$CONFIG_FILE"
    prepare_go_workspace
    ensure_go_runtime
    process_go_inventory

    print_summary_line 'Instaladas' "$INSTALLED"
    print_summary_line 'Já existentes' "$EXISTING"
    print_summary_line 'Atualizadas' '0'
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' '0'
    print_summary_line 'Falhas' "$FAILED"
    print_summary_line 'Log' "$LOG_FILE"
    if [[ "$FAILED" -eq 0 ]]; then
        print_summary_line 'Status' "OK (${ARCHITECTURE})"
    else
        print_summary_line 'Status' "PARCIAL (${ARCHITECTURE})"
    fi
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"

    if [[ "${#INSTALLED_ITEMS[@]}" -gt 0 ]]; then
        print_result_list 'Instalado nesta execução:' "${INSTALLED_ITEMS[@]}"
    else
        print_result_list 'Instalado nesta execução:'
    fi
    if [[ "$FAILED" -gt 0 ]]; then
        print_result_list 'Não foi possível instalar:' "${FAILED_ITEMS[@]}"
    fi
}

main "$@"
