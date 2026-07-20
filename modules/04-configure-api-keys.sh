#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 04
# NOME..........: Configuração das Chaves de API
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Preparar uma estrutura segura para armazenar, editar, validar, exportar e
# reutilizar chaves de API usadas por ferramentas de cibersegurança.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma execução com sudo.
# 2. Confirma que o usuário real é diogo por meio de SUDO_USER.
# 3. Descobre o home real com getent passwd diogo.
# 4. Cria ~/.config/kali-setup com permissão 700.
# 5. Cria ~/.config/kali-setup/api-keys.env com permissão 600.
# 6. Preserva valores existentes e adiciona somente variáveis ausentes.
# 7. Instala utilitários em ~/.local/bin sem armazenar secrets no repositório.
# 8. Cria ~/.config/subfinder/provider-config.yaml quando permitido.
# 9. Valida proprietário, grupo, permissões e formato final.
#
# COMO CADASTRAR E UTILIZAR AS CHAVES
#
# 1. Execute este módulo uma primeira vez:
#    sudo ./modules/04-configure-api-keys.sh
# 2. Abra o arquivo central de chaves executando o utilitário abaixo. Ele é um
#    comando, não um diretório; portanto, não use "cd edit-api-keys":
#    ~/.local/bin/edit-api-keys
# 3. Valide o arquivo sem exibir os valores cadastrados:
#    ~/.local/bin/check-api-keys
# 4. Depois de adicionar ou alterar uma chave usada pelo Subfinder, execute este
#    módulo novamente e confirme a substituição do provider-config.yaml. O módulo
#    lê o arquivo central e atualiza ~/.config/subfinder/provider-config.yaml.
# 5. Para ferramentas que aceitam as variáveis previstas por este projeto,
#    carregue-as somente no terminal atual com:
#    source ~/.local/bin/export-api-keys
#
# ESCOPO DA CONFIGURAÇÃO
#
# - O arquivo central de chaves é ~/.config/kali-setup/api-keys.env.
# - O Subfinder recebe uma configuração nativa gerada por este módulo e utiliza
#   ~/.config/subfinder/provider-config.yaml automaticamente em seus comandos.
# - Este módulo não cria configurações nativas para todas as outras ferramentas.
# - Ferramentas compatíveis com variáveis de ambiente podem usar as chaves após
#   o carregamento de ~/.local/bin/export-api-keys no terminal atual.
# - Ferramentas que exigem login, comando de inicialização ou arquivo próprio
#   ainda precisam ser configuradas conforme sua documentação oficial.
# - As variáveis não são instaladas globalmente nem carregadas automaticamente
#   em novos terminais. Essa decisão reduz a exposição desnecessária de secrets.
#
# RISCOS CONTROLADOS
#
# - Secrets não devem ser exibidos no terminal, logs, histórico ou Git.
# - Links simbólicos podem redirecionar escrita privilegiada para outro arquivo.
# - Permissões permissivas permitem leitura por outros usuários.
# - Reescrever um arquivo de secrets pode destruir valores já cadastrados.
# - Backups em texto puro criam uma segunda cópia sensível e difícil de rastrear.
#
# Por isso, o módulo usa umask 077, valida caminhos antes de escrever, recusa
# links simbólicos, preserva valores existentes, não cria backup em texto puro,
# não recebe secrets por argumentos e não faz nenhuma requisição externa.
###############################################################################


###############################################################################
# CONFIGURAÇÕES DE SEGURANÇA DO BASH
###############################################################################

# -E herda o trap ERR dentro de funções.
# -e interrompe o fluxo normal quando uma validação falha.
# -u impede uso acidental de variável vazia ou não definida em caminho sensível.
# -o pipefail mantém o padrão do projeto para pipelines futuros.
set -Eeuo pipefail

# PATH fixo reduz o risco de executar um binário falso colocado em diretório
# controlado pelo usuário durante uma execução com sudo.
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

# Localidade previsível para comparações textuais.
LC_ALL='C'
export LC_ALL

# Novos arquivos nascem sem permissão para grupo e outros usuários.
umask 077


###############################################################################
# CONFIGURAÇÃO DO MÓDULO
###############################################################################

readonly TARGET_USER='diogo'
readonly TARGET_GROUP='diogo'
readonly NEXT_MODULE='05-create-directories.sh'

readonly API_CONFIG_RELATIVE_DIR='.config/kali-setup'
readonly API_FILE_NAME='api-keys.env'
readonly SUBFINDER_RELATIVE_DIR='.config/subfinder'
readonly SUBFINDER_FILE_NAME='provider-config.yaml'
readonly LOCAL_BIN_RELATIVE_DIR='.local/bin'

readonly REQUIRED_DIR_MODE='700'
readonly REQUIRED_SECRET_FILE_MODE='600'
readonly REQUIRED_HELPER_MODE='700'


###############################################################################
# ESTADO DA EXECUÇÃO
###############################################################################

REAL_USER=''
REAL_HOME=''
REAL_GROUP=''
REPO_ROOT=''
MODULE_DIR=''

API_DIR=''
API_FILE=''
SUBFINDER_DIR=''
SUBFINDER_FILE=''
LOCAL_BIN_DIR=''

API_EXAMPLE_FILE=''
SUBFINDER_EXAMPLE_FILE=''
EDIT_SCRIPT_SOURCE=''
CHECK_SCRIPT_SOURCE=''
EXPORT_SCRIPT_SOURCE=''

TEMP_SUBFINDER_FILE=''
PARSED_NAME=''
PARSED_VALUE=''

API_TOTAL='0'
API_CONFIGURED='0'
API_MISSING='0'
API_ADDED='0'
SUBFINDER_STATUS='Não alterado'
FINAL_STATUS='OK'

readonly API_VARIABLES=(
    'SHODAN_API_KEY'
    'SECURITYTRAILS_API_KEY'
    'VIRUSTOTAL_API_KEY'
    'CENSYS_API_TOKEN'
    'GITHUB_TOKEN'
    'GITLAB_TOKEN'
    'PROJECTDISCOVERY_API_KEY'
    'HUNTER_API_KEY'
    'BUILTWITH_API_KEY'
    'BINARYEDGE_API_KEY'
    'FOFA_EMAIL'
    'FOFA_API_KEY'
    'ZOOMEYE_API_KEY'
    'FULLHUNT_API_KEY'
    'CHAOS_API_KEY'
    'INTELX_API_KEY'
    'SPYSE_API_KEY'
    'URLSCAN_API_KEY'
    'GREYNOISE_API_KEY'
    'ABUSEIPDB_API_KEY'
    'IPINFO_TOKEN'
    'WHOISXML_API_KEY'
    'NETLAS_API_KEY'
    'LEAKIX_API_KEY'
    'PULSEDIVE_API_KEY'
    'ONYPHE_API_KEY'
    'QUAKE_API_KEY'
    'PASSIVETOTAL_USERNAME'
    'PASSIVETOTAL_API_KEY'
)


###############################################################################
# CORES E MENSAGENS
###############################################################################

RED=''
GREEN=''
YELLOW=''
BLUE=''
NC=''

if [[ -t 1 ]]; then
    if [[ -z "${NO_COLOR:-}" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m'
    fi
fi

info() {
    printf '%b[INFO]%b %s\n' "$BLUE" "$NC" "$*"
}

success() {
    printf '%b[ OK ]%b %s\n' "$GREEN" "$NC" "$*"
}

warning() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*"
}

error() {
    printf '%b[ERRO]%b %s\n' "$RED" "$NC" "$*" >&2
}


###############################################################################
# TRATAMENTO DE ERROS E LIMPEZA
###############################################################################

cleanup_temporary_files() {
    if [[ -z "${TEMP_SUBFINDER_FILE:-}" ]]; then
        return 0
    fi

    if [[ "$TEMP_SUBFINDER_FILE" != "${SUBFINDER_FILE}.kali-setup."* ]]; then
        warning "Temporário fora do padrão esperado; remoção recusada."
        TEMP_SUBFINDER_FILE=''
        return 0
    fi

    if [[ -L "$TEMP_SUBFINDER_FILE" ]]; then
        warning "Temporário tornou-se link simbólico; remoção recusada."
        TEMP_SUBFINDER_FILE=''
        return 0
    fi

    if [[ -e "$TEMP_SUBFINDER_FILE" ]]; then
        if [[ -f "$TEMP_SUBFINDER_FILE" ]]; then
            if rm -- "$TEMP_SUBFINDER_FILE"; then
                info "Arquivo temporário removido."
            else
                warning "Não foi possível remover o temporário do Subfinder."
            fi
        else
            warning "Temporário não é arquivo regular; remoção recusada."
        fi
    fi

    TEMP_SUBFINDER_FILE=''
    return 0
}

handle_error() {
    local codigo_saida="$?"
    local comando_falhou="${BASH_COMMAND}"
    local linha_aproximada="${BASH_LINENO[0]:-${LINENO}}"

    trap - ERR
    set +e

    printf '\n' >&2
    error "O módulo encontrou um erro."
    error "Comando executado: ${comando_falhou}"
    error "Linha aproximada: ${linha_aproximada}"
    error "Código de saída: ${codigo_saida}"
    printf '\n' >&2

    cleanup_temporary_files
    exit "$codigo_saida"
}

trap handle_error ERR
trap cleanup_temporary_files EXIT


###############################################################################
# BANNER INICIAL
###############################################################################

print_banner() {
    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' '            KALI SETUP - MÓDULO 04'
    printf '%s\n' '          Configuração das Chaves de API'
    printf '%s\n' '============================================================'
    printf '\n'
}


###############################################################################
# VALIDAR COMANDOS
###############################################################################

require_command() {
    local comando="$1"

    # command -v confirma que o comando existe no PATH administrativo fixo.
    # Validar antes de modificar arquivos evita uma execução parcialmente feita.
    if command -v "$comando" >/dev/null 2>&1; then
        return 0
    fi

    error "Comando obrigatório não encontrado: ${comando}"
    exit 1
}

validate_required_commands() {
    info "Validando comandos necessários..."

    require_command chmod
    require_command chown
    require_command cmp
    require_command cp
    require_command dirname
    require_command getent
    require_command id
    require_command mkdir
    require_command mktemp
    require_command mv
    require_command pwd
    require_command rm
    require_command stat
    require_command touch

    success "Comandos obrigatórios encontrados."
}


###############################################################################
# DESCOBRIR CAMINHOS DO PROJETO
###############################################################################

discover_project_paths() {
    local origem_modulo="${BASH_SOURCE[0]}"
    local diretorio_bruto=''

    info "Descobrindo diretório do projeto..."

    diretorio_bruto="$(dirname -- "$origem_modulo")"

    if MODULE_DIR="$(cd -- "$diretorio_bruto"; pwd -P)"; then
        REPO_ROOT="$(dirname -- "$MODULE_DIR")"
    else
        error "Não foi possível resolver o diretório do módulo."
        exit 1
    fi

    API_EXAMPLE_FILE="${REPO_ROOT}/config/api-keys.env.example"
    SUBFINDER_EXAMPLE_FILE="${REPO_ROOT}/config/subfinder-provider-config.yaml.example"
    EDIT_SCRIPT_SOURCE="${REPO_ROOT}/scripts/edit-api-keys.sh"
    CHECK_SCRIPT_SOURCE="${REPO_ROOT}/scripts/check-api-keys.sh"
    EXPORT_SCRIPT_SOURCE="${REPO_ROOT}/scripts/export-api-keys.sh"

    success "Projeto localizado em: ${REPO_ROOT}"
}


###############################################################################
# VALIDAR PRIVILÉGIOS E USUÁRIO REAL
###############################################################################

validate_sudo_user() {
    local entrada_passwd=''
    local nome=''
    local senha=''
    local uid=''
    local gid=''
    local gecos=''
    local home=''
    local shell=''

    info "Verificando execução com sudo..."

    if [[ "$EUID" -ne 0 ]]; then
        error "Este módulo precisa ser executado com sudo."
        error "Use: sudo ./modules/04-configure-api-keys.sh"
        exit 1
    fi

    if [[ -z "${SUDO_USER:-}" ]]; then
        error "SUDO_USER não está definido. Execute com sudo a partir do usuário real."
        exit 1
    fi

    REAL_USER="$SUDO_USER"

    if [[ "$REAL_USER" != "$TARGET_USER" ]]; then
        error "Usuário real recusado: esperado ${TARGET_USER}, encontrado ${REAL_USER}."
        exit 1
    fi

    if command -v getent >/dev/null 2>&1; then
        :
    else
        error "Comando obrigatório não encontrado: getent"
        exit 1
    fi

    if entrada_passwd="$(getent passwd "$TARGET_USER")"; then
        IFS=':' read -r nome senha uid gid gecos home shell <<< "$entrada_passwd"
        if [[ -n "$home" ]]; then
            REAL_HOME="$home"
        else
            error "Home vazio no cadastro de ${TARGET_USER}."
            exit 1
        fi
    else
        error "Usuário ${TARGET_USER} não encontrado via getent."
        exit 1
    fi

    if getent group "$TARGET_GROUP" >/dev/null 2>&1; then
        REAL_GROUP="$TARGET_GROUP"
    else
        error "Grupo ${TARGET_GROUP} não encontrado."
        exit 1
    fi

    API_DIR="${REAL_HOME}/${API_CONFIG_RELATIVE_DIR}"
    API_FILE="${API_DIR}/${API_FILE_NAME}"
    SUBFINDER_DIR="${REAL_HOME}/${SUBFINDER_RELATIVE_DIR}"
    SUBFINDER_FILE="${SUBFINDER_DIR}/${SUBFINDER_FILE_NAME}"
    LOCAL_BIN_DIR="${REAL_HOME}/${LOCAL_BIN_RELATIVE_DIR}"

    success "Usuário real confirmado: ${REAL_USER}"
    success "Home real confirmado: ${REAL_HOME}"
}


###############################################################################
# VALIDAÇÕES DE CAMINHO
###############################################################################

validate_absolute_path() {
    local caminho="$1"
    local descricao="$2"

    if [[ "$caminho" != /* ]]; then
        error "${descricao} não é caminho absoluto: ${caminho}"
        exit 1
    fi
}

validate_regular_file_in_repo() {
    local caminho="$1"
    local descricao="$2"

    validate_absolute_path "$caminho" "$descricao"

    if [[ -L "$caminho" ]]; then
        error "${descricao} recusado: link simbólico não é permitido."
        exit 1
    fi

    if [[ ! -f "$caminho" ]]; then
        error "${descricao} não encontrado: ${caminho}"
        exit 1
    fi
}

validate_project_files() {
    info "Validando arquivos do projeto que serão usados pelo módulo..."

    validate_regular_file_in_repo "$API_EXAMPLE_FILE" 'Modelo de chaves'
    validate_regular_file_in_repo "$SUBFINDER_EXAMPLE_FILE" 'Modelo do Subfinder'
    validate_regular_file_in_repo "$EDIT_SCRIPT_SOURCE" 'Script de edição'
    validate_regular_file_in_repo "$CHECK_SCRIPT_SOURCE" 'Script de validação'
    validate_regular_file_in_repo "$EXPORT_SCRIPT_SOURCE" 'Script de exportação'

    success "Arquivos do projeto validados."
}


###############################################################################
# CRIAR E VALIDAR DIRETÓRIOS SEGUROS
###############################################################################

ensure_secure_directory() {
    local diretorio="$1"
    local descricao="$2"
    local modo_atual=''
    local dono_atual=''
    local grupo_atual=''

    validate_absolute_path "$diretorio" "$descricao"

    if [[ -L "$diretorio" ]]; then
        error "${descricao} recusado: link simbólico não é permitido."
        exit 1
    fi

    if [[ -e "$diretorio" ]]; then
        if [[ ! -d "$diretorio" ]]; then
            error "${descricao} existe, mas não é diretório."
            exit 1
        fi
    else
        # mkdir -p cria a árvore necessária sem erro se o diretório já existir.
        # Como o caminho foi validado e é absoluto, não depende do diretório atual.
        mkdir -p -- "$diretorio"
        success "${descricao} criado."
    fi

    chown "${TARGET_USER}:${TARGET_GROUP}" "$diretorio"
    chmod "$REQUIRED_DIR_MODE" "$diretorio"

    modo_atual="$(stat -c '%a' "$diretorio")"
    dono_atual="$(stat -c '%U' "$diretorio")"
    grupo_atual="$(stat -c '%G' "$diretorio")"

    if [[ "$modo_atual" != "$REQUIRED_DIR_MODE" ]]; then
        error "${descricao} ficou com permissão inesperada: ${modo_atual}"
        exit 1
    fi

    if [[ "$dono_atual" != "$TARGET_USER" ]]; then
        error "${descricao} ficou com proprietário inesperado: ${dono_atual}"
        exit 1
    fi

    if [[ "$grupo_atual" != "$TARGET_GROUP" ]]; then
        error "${descricao} ficou com grupo inesperado: ${grupo_atual}"
        exit 1
    fi

    success "${descricao} validado com permissão ${REQUIRED_DIR_MODE}."
}


###############################################################################
# PARSER DO ARQUIVO DE CHAVES
###############################################################################

is_allowed_variable() {
    local nome="$1"

    case "$nome" in
        SHODAN_API_KEY|SECURITYTRAILS_API_KEY|VIRUSTOTAL_API_KEY|CENSYS_API_TOKEN|GITHUB_TOKEN|GITLAB_TOKEN|PROJECTDISCOVERY_API_KEY|HUNTER_API_KEY|BUILTWITH_API_KEY|BINARYEDGE_API_KEY|FOFA_EMAIL|FOFA_API_KEY|ZOOMEYE_API_KEY|FULLHUNT_API_KEY|CHAOS_API_KEY|INTELX_API_KEY|SPYSE_API_KEY|URLSCAN_API_KEY|GREYNOISE_API_KEY|ABUSEIPDB_API_KEY|IPINFO_TOKEN|WHOISXML_API_KEY|NETLAS_API_KEY|LEAKIX_API_KEY|PULSEDIVE_API_KEY|ONYPHE_API_KEY|QUAKE_API_KEY|PASSIVETOTAL_USERNAME|PASSIVETOTAL_API_KEY)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

parse_assignment_line() {
    local linha="$1"

    PARSED_NAME=''
    PARSED_VALUE=''

    if [[ "$linha" =~ ^([A-Z][A-Z0-9_]*)=\"(.*)\"$ ]]; then
        PARSED_NAME="${BASH_REMATCH[1]}"
        PARSED_VALUE="${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

get_secret_value() {
    local nome_procurado="$1"
    local linha=''

    while IFS= read -r linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi

        if [[ "$linha" == \#* ]]; then
            continue
        fi

        if parse_assignment_line "$linha"; then
            if [[ "$PARSED_NAME" == "$nome_procurado" ]]; then
                printf '%s' "$PARSED_VALUE"
                return 0
            fi
        fi
    done < "$API_FILE"

    return 0
}


###############################################################################
# CRIAR E VALIDAR ARQUIVO PRINCIPAL DE CHAVES
###############################################################################

create_api_file_if_needed() {
    if [[ -L "$API_FILE" ]]; then
        error "Arquivo de chaves recusado: link simbólico não é permitido."
        exit 1
    fi

    if [[ -e "$API_FILE" ]]; then
        if [[ ! -f "$API_FILE" ]]; then
            error "Arquivo de chaves existe, mas não é arquivo regular."
            exit 1
        fi

        success "Arquivo de chaves já existe; valores serão preservados."
        return 0
    fi

    # O modelo contém apenas variáveis vazias. A cópia cria a estrutura inicial
    # sem inserir credenciais reais e sem imprimir conteúdo no terminal.
    cp --no-target-directory -- "$API_EXAMPLE_FILE" "$API_FILE"
    chown "${TARGET_USER}:${TARGET_GROUP}" "$API_FILE"
    chmod "$REQUIRED_SECRET_FILE_MODE" "$API_FILE"

    success "Arquivo de chaves criado sem credenciais reais."
}

validate_api_file_security() {
    local modo_atual=''
    local dono_atual=''
    local grupo_atual=''

    if [[ -L "$API_FILE" ]]; then
        error "Arquivo de chaves recusado: link simbólico não é permitido."
        exit 1
    fi

    if [[ ! -f "$API_FILE" ]]; then
        error "Arquivo de chaves não é regular: ${API_FILE}"
        exit 1
    fi

    dono_atual="$(stat -c '%U' "$API_FILE")"
    grupo_atual="$(stat -c '%G' "$API_FILE")"

    if [[ "$dono_atual" != "$TARGET_USER" ]]; then
        error "Arquivo de chaves pertence a ${dono_atual}; esperado ${TARGET_USER}."
        exit 1
    fi

    if [[ "$grupo_atual" != "$TARGET_GROUP" ]]; then
        error "Arquivo de chaves pertence ao grupo ${grupo_atual}; esperado ${TARGET_GROUP}."
        exit 1
    fi

    chmod "$REQUIRED_SECRET_FILE_MODE" "$API_FILE"

    modo_atual="$(stat -c '%a' "$API_FILE")"

    if [[ "$modo_atual" != "$REQUIRED_SECRET_FILE_MODE" ]]; then
        error "Arquivo de chaves ficou com permissão inesperada: ${modo_atual}"
        exit 1
    fi

    success "Arquivo de chaves validado com permissão ${REQUIRED_SECRET_FILE_MODE}."
}

validate_api_content() {
    local linha=''
    local numero_linha=0
    local nomes_vistos=' '

    API_TOTAL="${#API_VARIABLES[@]}"
    API_CONFIGURED='0'
    API_MISSING='0'

    while IFS= read -r linha; do
        numero_linha=$((numero_linha + 1))

        if [[ -z "$linha" ]]; then
            continue
        fi

        if [[ "$linha" == \#* ]]; then
            continue
        fi

        if parse_assignment_line "$linha"; then
            if is_allowed_variable "$PARSED_NAME"; then
                case "$nomes_vistos" in
                    *" ${PARSED_NAME} "*)
                        error "Variável duplicada detectada sem exibir valor: ${PARSED_NAME}"
                        exit 1
                        ;;
                    *)
                        nomes_vistos="${nomes_vistos}${PARSED_NAME} "
                        ;;
                esac
            else
                error "Variável não autorizada na linha ${numero_linha}: ${PARSED_NAME}"
                exit 1
            fi
        else
            error "Linha inválida no arquivo de chaves: ${numero_linha}"
            error "O conteúdo da linha não será exibido por segurança."
            exit 1
        fi
    done < "$API_FILE"
}

append_missing_api_variables() {
    local nome=''
    local adicionou=0

    for nome in "${API_VARIABLES[@]}"; do
        if variable_exists_in_file "$nome"; then
            :
        else
            if [[ "$adicionou" -eq 0 ]]; then
                printf '\n' >> "$API_FILE"
                adicionou=1
            fi

            printf '%s=""\n' "$nome" >> "$API_FILE"
            API_ADDED=$((API_ADDED + 1))
        fi
    done

    if [[ "$API_ADDED" -gt 0 ]]; then
        success "Variáveis ausentes adicionadas sem alterar valores existentes."
    else
        success "Nenhuma variável ausente encontrada."
    fi
}

variable_exists_in_file() {
    local nome_procurado="$1"
    local linha=''

    while IFS= read -r linha; do
        if parse_assignment_line "$linha"; then
            if [[ "$PARSED_NAME" == "$nome_procurado" ]]; then
                return 0
            fi
        fi
    done < "$API_FILE"

    return 1
}

count_configured_apis() {
    local nome=''
    local valor=''

    API_CONFIGURED='0'
    API_MISSING='0'

    for nome in "${API_VARIABLES[@]}"; do
        valor="$(get_secret_value "$nome")"

        if [[ -n "$valor" ]]; then
            API_CONFIGURED=$((API_CONFIGURED + 1))
        else
            API_MISSING=$((API_MISSING + 1))
        fi
    done
}


###############################################################################
# INSTALAR UTILITÁRIOS EM ~/.local/bin
###############################################################################

install_helper_script() {
    local origem="$1"
    local destino="$2"
    local descricao="$3"
    local precisa_copiar=1

    validate_regular_file_in_repo "$origem" "$descricao"

    if [[ -L "$destino" ]]; then
        error "Destino recusado por ser link simbólico: ${destino}"
        exit 1
    fi

    if [[ -e "$destino" ]]; then
        if [[ ! -f "$destino" ]]; then
            error "Destino existe, mas não é arquivo regular: ${destino}"
            exit 1
        fi

        if cmp --silent -- "$origem" "$destino"; then
            precisa_copiar=0
        fi
    fi

    if [[ "$precisa_copiar" -eq 1 ]]; then
        cp --no-target-directory -- "$origem" "$destino"
        success "${descricao} instalado em ${destino}."
    else
        success "${descricao} já estava atualizado."
    fi

    chown "${TARGET_USER}:${TARGET_GROUP}" "$destino"
    chmod "$REQUIRED_HELPER_MODE" "$destino"
}

install_user_helpers() {
    info "Instalando utilitários em ~/.local/bin..."

    ensure_secure_directory "$LOCAL_BIN_DIR" 'Diretório de utilitários locais'

    install_helper_script "$EDIT_SCRIPT_SOURCE" "${LOCAL_BIN_DIR}/edit-api-keys" 'Editor de chaves'
    install_helper_script "$CHECK_SCRIPT_SOURCE" "${LOCAL_BIN_DIR}/check-api-keys" 'Validador de chaves'
    install_helper_script "$EXPORT_SCRIPT_SOURCE" "${LOCAL_BIN_DIR}/export-api-keys" 'Exportador de chaves'
}


###############################################################################
# GERAR CONFIGURAÇÃO DO SUBFINDER
###############################################################################

contains_colon() {
    local valor="$1"

    case "$valor" in
        *:*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

yaml_quote() {
    local valor="$1"

    valor="${valor//\\/\\\\}"
    valor="${valor//\"/\\\"}"
    printf '"%s"' "$valor"
}

write_yaml_provider() {
    local arquivo="$1"
    local provedor="$2"
    local valor="$3"
    local valor_seguro=''

    if [[ -n "$valor" ]]; then
        valor_seguro="$(yaml_quote "$valor")"
        printf '%s:\n' "$provedor" >> "$arquivo"
        printf '  - %s\n' "$valor_seguro" >> "$arquivo"
    else
        printf '%s: []\n' "$provedor" >> "$arquivo"
    fi
}

confirm_subfinder_replace() {
    local resposta=''

    if [[ ! -s "$SUBFINDER_FILE" ]]; then
        return 0
    fi

    warning "O arquivo real do Subfinder já existe e contém dados."
    warning "Nenhum backup em texto puro será criado."
    printf 'Substituir conscientemente %s? [s/N]: ' "$SUBFINDER_FILE"

    if read -r resposta; then
        case "$resposta" in
            s|S|sim|SIM)
                return 0
                ;;
            *)
                SUBFINDER_STATUS='Mantido existente'
                warning "Configuração existente do Subfinder foi preservada."
                return 1
                ;;
        esac
    fi

    SUBFINDER_STATUS='Mantido existente'
    warning "Sem confirmação interativa; configuração existente foi preservada."
    return 1
}

build_subfinder_config() {
    local binaryedge=''
    local builtwith=''
    local censys=''
    local chaos=''
    local fofa_email=''
    local fofa_key=''
    local fofa=''
    local fullhunt=''
    local github=''
    local hunter=''
    local intelx=''
    local passivetotal_user=''
    local passivetotal_key=''
    local passivetotal=''
    local securitytrails=''
    local shodan=''
    local virustotal=''
    local whoisxmlapi=''
    local zoomeyeapi=''
    local quake=''

    ensure_secure_directory "$SUBFINDER_DIR" 'Diretório do Subfinder'

    if [[ -L "$SUBFINDER_FILE" ]]; then
        error "Configuração do Subfinder recusada: link simbólico não é permitido."
        exit 1
    fi

    if [[ -e "$SUBFINDER_FILE" ]]; then
        if [[ ! -f "$SUBFINDER_FILE" ]]; then
            error "Configuração do Subfinder existe, mas não é arquivo regular."
            exit 1
        fi

        if confirm_subfinder_replace; then
            :
        else
            chmod "$REQUIRED_SECRET_FILE_MODE" "$SUBFINDER_FILE"
            chown "${TARGET_USER}:${TARGET_GROUP}" "$SUBFINDER_FILE"
            return 0
        fi
    fi

    binaryedge="$(get_secret_value 'BINARYEDGE_API_KEY')"
    builtwith="$(get_secret_value 'BUILTWITH_API_KEY')"
    censys="$(get_secret_value 'CENSYS_API_TOKEN')"
    chaos="$(get_secret_value 'CHAOS_API_KEY')"

    if [[ -z "$chaos" ]]; then
        chaos="$(get_secret_value 'PROJECTDISCOVERY_API_KEY')"
    fi

    fofa_email="$(get_secret_value 'FOFA_EMAIL')"
    fofa_key="$(get_secret_value 'FOFA_API_KEY')"

    if [[ -n "$fofa_email" ]]; then
        if [[ -n "$fofa_key" ]]; then
            fofa="${fofa_email}:${fofa_key}"
        fi
    fi

    fullhunt="$(get_secret_value 'FULLHUNT_API_KEY')"
    github="$(get_secret_value 'GITHUB_TOKEN')"
    hunter="$(get_secret_value 'HUNTER_API_KEY')"
    intelx="$(get_secret_value 'INTELX_API_KEY')"
    passivetotal_user="$(get_secret_value 'PASSIVETOTAL_USERNAME')"
    passivetotal_key="$(get_secret_value 'PASSIVETOTAL_API_KEY')"

    if [[ -n "$passivetotal_user" ]]; then
        if [[ -n "$passivetotal_key" ]]; then
            passivetotal="${passivetotal_user}:${passivetotal_key}"
        fi
    fi

    securitytrails="$(get_secret_value 'SECURITYTRAILS_API_KEY')"
    shodan="$(get_secret_value 'SHODAN_API_KEY')"
    virustotal="$(get_secret_value 'VIRUSTOTAL_API_KEY')"
    whoisxmlapi="$(get_secret_value 'WHOISXML_API_KEY')"
    zoomeyeapi="$(get_secret_value 'ZOOMEYE_API_KEY')"
    quake="$(get_secret_value 'QUAKE_API_KEY')"

    if [[ -n "$zoomeyeapi" ]]; then
        if contains_colon "$zoomeyeapi"; then
            :
        else
            warning "ZOOMEYE_API_KEY precisa usar o formato host:chave para o Subfinder; valor não gravado."
            zoomeyeapi=''
        fi
    fi

    if [[ -n "$intelx" ]]; then
        if contains_colon "$intelx"; then
            :
        else
            warning "INTELX_API_KEY precisa usar formato composto para o Subfinder; valor não gravado."
            intelx=''
        fi
    fi

    TEMP_SUBFINDER_FILE="$(mktemp "${SUBFINDER_FILE}.kali-setup.XXXXXX")"
    chmod "$REQUIRED_SECRET_FILE_MODE" "$TEMP_SUBFINDER_FILE"
    chown "${TARGET_USER}:${TARGET_GROUP}" "$TEMP_SUBFINDER_FILE"

    printf '%s\n' '# Arquivo gerado pelo KALI SETUP.' > "$TEMP_SUBFINDER_FILE"
    printf '%s\n' '# Não publique este arquivo. Ele pode conter credenciais reais.' >> "$TEMP_SUBFINDER_FILE"
    printf '\n' >> "$TEMP_SUBFINDER_FILE"

    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'binaryedge' "$binaryedge"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'builtwith' "$builtwith"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'censys' "$censys"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'chaos' "$chaos"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'fofa' "$fofa"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'fullhunt' "$fullhunt"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'github' "$github"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'hunter' "$hunter"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'intelx' "$intelx"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'passivetotal' "$passivetotal"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'securitytrails' "$securitytrails"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'shodan' "$shodan"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'virustotal' "$virustotal"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'whoisxmlapi' "$whoisxmlapi"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'zoomeyeapi' "$zoomeyeapi"
    write_yaml_provider "$TEMP_SUBFINDER_FILE" 'quake' "$quake"

    mv --no-target-directory -- "$TEMP_SUBFINDER_FILE" "$SUBFINDER_FILE"
    TEMP_SUBFINDER_FILE=''

    chown "${TARGET_USER}:${TARGET_GROUP}" "$SUBFINDER_FILE"
    chmod "$REQUIRED_SECRET_FILE_MODE" "$SUBFINDER_FILE"

    SUBFINDER_STATUS='Gerado/atualizado'
    success "Configuração do Subfinder preparada sem exibir credenciais."
}


###############################################################################
# VALIDAÇÃO FINAL
###############################################################################

validate_final_state() {
    local api_mode=''
    local api_owner=''
    local api_group=''
    local subfinder_mode=''
    local subfinder_owner=''
    local subfinder_group=''

    validate_api_file_security
    validate_api_content
    count_configured_apis

    api_mode="$(stat -c '%a' "$API_FILE")"
    api_owner="$(stat -c '%U' "$API_FILE")"
    api_group="$(stat -c '%G' "$API_FILE")"

    if [[ "$api_mode" != "$REQUIRED_SECRET_FILE_MODE" ]]; then
        FINAL_STATUS='ERRO'
    fi

    if [[ "$api_owner" != "$TARGET_USER" ]]; then
        FINAL_STATUS='ERRO'
    fi

    if [[ "$api_group" != "$TARGET_GROUP" ]]; then
        FINAL_STATUS='ERRO'
    fi

    if [[ -f "$SUBFINDER_FILE" ]]; then
        if [[ ! -L "$SUBFINDER_FILE" ]]; then
            subfinder_mode="$(stat -c '%a' "$SUBFINDER_FILE")"
            subfinder_owner="$(stat -c '%U' "$SUBFINDER_FILE")"
            subfinder_group="$(stat -c '%G' "$SUBFINDER_FILE")"

            if [[ "$subfinder_mode" != "$REQUIRED_SECRET_FILE_MODE" ]]; then
                FINAL_STATUS='ERRO'
            fi

            if [[ "$subfinder_owner" != "$TARGET_USER" ]]; then
                FINAL_STATUS='ERRO'
            fi

            if [[ "$subfinder_group" != "$TARGET_GROUP" ]]; then
                FINAL_STATUS='ERRO'
            fi
        else
            FINAL_STATUS='ERRO'
        fi
    fi

    if [[ "$FINAL_STATUS" == 'OK' ]]; then
        success "Validação final concluída."
    else
        error "Validação final encontrou inconsistências."
        exit 1
    fi
}


###############################################################################
# RESUMO FINAL
###############################################################################

print_summary() {
    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' '             MÓDULO 04 CONCLUÍDO'
    printf '%s\n' '============================================================'
    printf '\n'
    printf '%-23s: %s\n' 'Arquivo de APIs' "$API_FILE"
    printf '%-23s: %s\n' 'Diretório' "$API_DIR"
    printf '%-23s: %s:%s\n' 'Proprietário' "$TARGET_USER" "$TARGET_GROUP"
    printf '%-23s: %s\n' 'Permissão' "$REQUIRED_SECRET_FILE_MODE"
    printf '%-23s: %s\n' 'Modelo' "$API_EXAMPLE_FILE"
    printf '%-23s: %s\n' 'Subfinder config' "$SUBFINDER_STATUS"
    printf '%-23s: %s\n' 'Utilitários' "$LOCAL_BIN_DIR"
    printf '%-23s: %s\n' 'Status' "$FINAL_STATUS"
    printf '%-23s: %s\n' 'Próximo módulo' "$NEXT_MODULE"
    printf '\n'
}


###############################################################################
# EXECUÇÃO PRINCIPAL
###############################################################################

main() {
    print_banner

    info "Objetivo: preparar estrutura segura de chaves de API sem inserir secrets reais."
    info "Fluxo: validar sudo, criar arquivos privados, instalar utilitários e preparar Subfinder."
    warning "Risco controlado: nenhum valor de chave será exibido ou salvo no repositório."
    printf '\n'

    validate_sudo_user
    validate_required_commands
    discover_project_paths
    validate_project_files

    ensure_secure_directory "$API_DIR" 'Diretório de chaves de API'
    create_api_file_if_needed
    validate_api_file_security
    validate_api_content
    append_missing_api_variables
    validate_api_content
    count_configured_apis

    install_user_helpers
    build_subfinder_config
    validate_final_state
    print_summary
}

main "$@"
