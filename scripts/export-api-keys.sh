#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# SCRIPT........: export-api-keys
# NOME..........: Exportação controlada de chaves de API
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO......: Exportar chaves permitidas sem executar o arquivo de secrets
#
# Uso recomendado:
#
# source ~/.local/bin/export-api-keys
#
# O script também pode ser executado diretamente para validar o arquivo, mas as
# variáveis exportadas nesse modo ficam apenas no processo filho e desaparecem
# ao final da execução. Para afetar o shell atual, use source.
#
# FLUXO DE EXECUÇÃO
#
# 1. Valida que o arquivo real existe e possui permissão segura.
# 2. Lê apenas linhas no formato NOME="valor".
# 3. Aceita somente variáveis presentes na allowlist.
# 4. Exporta variáveis para o shell atual quando usado com source.
#
# RISCOS CONTROLADOS
#
# O script não usa eval e não executa o arquivo de secrets como código. Ele faz
# parsing controlado para reduzir risco de injeção.
###############################################################################

umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

LC_ALL='C'
export LC_ALL

TARGET_USER='diogo'
TARGET_GROUP='diogo'
CONFIG_DIR_NAME='.config/kali-setup'
API_FILE_NAME='api-keys.env'

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

API_VARIABLES=(
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

REAL_HOME=''
API_FILE=''
PARSED_NAME=''
PARSED_VALUE=''
EXPORTED_COUNT=0
IS_SOURCED=0

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    IS_SOURCED=1
fi

return_or_exit() {
    local codigo_saida="$1"

    if [[ "$IS_SOURCED" -eq 1 ]]; then
        return "$codigo_saida"
    fi

    exit "$codigo_saida"
}

require_command() {
    local comando="$1"

    if command -v "$comando" >/dev/null 2>&1; then
        return 0
    fi

    error "Comando obrigatório não encontrado: ${comando}"
    return_or_exit 1
}

get_user_home() {
    local entrada_passwd=''
    local nome=''
    local senha=''
    local uid=''
    local gid=''
    local gecos=''
    local home=''
    local shell=''

    if entrada_passwd="$(getent passwd "$TARGET_USER")"; then
        IFS=':' read -r nome senha uid gid gecos home shell <<< "$entrada_passwd"
        if [[ -n "$home" ]]; then
            REAL_HOME="$home"
            API_FILE="${REAL_HOME}/${CONFIG_DIR_NAME}/${API_FILE_NAME}"
            return 0
        fi
    fi

    error "Não foi possível obter o home real de ${TARGET_USER}."
    return_or_exit 1
}

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

validate_file_security() {
    local permissao=''
    local proprietario=''
    local grupo=''

    if [[ ! -e "$API_FILE" ]]; then
        error "Arquivo de chaves não encontrado: ${API_FILE}"
        return_or_exit 1
    fi

    if [[ -L "$API_FILE" ]]; then
        error "Arquivo recusado: links simbólicos não são permitidos."
        return_or_exit 1
    fi

    if [[ ! -f "$API_FILE" ]]; then
        error "Arquivo recusado: o caminho não é um arquivo regular."
        return_or_exit 1
    fi

    permissao="$(stat -c '%a' "$API_FILE")"
    proprietario="$(stat -c '%U' "$API_FILE")"
    grupo="$(stat -c '%G' "$API_FILE")"

    if [[ "$proprietario" != "$TARGET_USER" ]]; then
        error "Proprietário inseguro: ${proprietario}"
        return_or_exit 1
    fi

    if [[ "$grupo" != "$TARGET_GROUP" ]]; then
        error "Grupo inseguro: ${grupo}"
        return_or_exit 1
    fi

    if [[ "$permissao" != '600' ]]; then
        error "Permissão insegura: ${permissao}"
        return_or_exit 1
    fi
}

validate_and_export() {
    local linha=''
    local numero_linha=0
    local nomes_vistos=' '

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
                        error "Variável duplicada no arquivo de chaves: ${PARSED_NAME}"
                        return_or_exit 1
                        ;;
                    *)
                        nomes_vistos="${nomes_vistos}${PARSED_NAME} "
                        ;;
                esac

                export "${PARSED_NAME}=${PARSED_VALUE}"

                if [[ -n "$PARSED_VALUE" ]]; then
                    EXPORTED_COUNT=$((EXPORTED_COUNT + 1))
                fi
            else
                error "Variável não autorizada na linha ${numero_linha}: ${PARSED_NAME}"
                return_or_exit 1
            fi
        else
            error "Linha inválida no arquivo de chaves: ${numero_linha}"
            error "Formato aceito: NOME_VARIAVEL=\"valor\""
            return_or_exit 1
        fi
    done < "$API_FILE"
}

main() {
    require_command getent
    require_command stat

    get_user_home
    validate_file_security
    validate_and_export

    if [[ "$IS_SOURCED" -eq 1 ]]; then
        success "${EXPORTED_COUNT} chave(s) configurada(s) exportada(s) sem exibir valores."
    else
        warning "Executado como processo filho; use source para exportar no shell atual."
        success "${EXPORTED_COUNT} chave(s) configurada(s) validada(s) sem exibir valores."
    fi
}

main "$@"
