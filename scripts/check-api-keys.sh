#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# SCRIPT........: check-api-keys
# NOME..........: Validação segura de chaves de API
# AUTOR.........: Diogo Frota
# OBJETIVO......: Validar o arquivo real de chaves sem exibir secrets
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# Este script verifica existência, tipo, proprietário, grupo, permissões e
# formato do arquivo ~/.config/kali-setup/api-keys.env. Ele não faz requisições
# externas, não testa credenciais em APIs e nunca imprime valores completos.
#
# FLUXO DE EXECUÇÃO
#
# 1. Localiza o arquivo real de chaves no home do usuário alvo.
# 2. Recusa links simbólicos e caminhos inseguros.
# 3. Valida proprietário, grupo e permissão.
# 4. Valida nomes de variáveis permitidas.
# 5. Conta chaves configuradas e ausentes sem imprimir valores.
#
# RISCOS CONTROLADOS
#
# Secrets não devem aparecer em terminal, logs ou histórico. Por isso o script
# valida metadados e formato, mas nunca exibe o conteúdo das chaves.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

LC_ALL='C'
export LC_ALL

readonly TARGET_USER='diogo'
readonly TARGET_GROUP='diogo'
readonly CONFIG_DIR_NAME='.config/kali-setup'
readonly API_FILE_NAME='api-keys.env'
readonly FUTURE_ONLINE_FLAG='--online'

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

handle_error() {
    local codigo_saida="$?"
    local comando_falhou="${BASH_COMMAND}"
    local linha_aproximada="${BASH_LINENO[0]:-${LINENO}}"

    printf '\n' >&2
    error "A validação encontrou um erro inesperado."
    error "Comando executado: ${comando_falhou}"
    error "Linha aproximada: ${linha_aproximada}"
    error "Código de saída: ${codigo_saida}"
    printf '\n' >&2

    exit "$codigo_saida"
}

trap handle_error ERR

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

REAL_HOME=''
API_FILE=''
PARSED_NAME=''
PARSED_VALUE=''
INVALID_LINES=0
DUPLICATE_LINES=0
CONFIGURED_COUNT=0
MISSING_COUNT=0
STATUS='SEGURO'

###############################################################################
# VALIDAR COMANDOS NECESSÁRIOS
###############################################################################

require_command() {
    local comando="$1"

    # command -v consulta o PATH efetivo e retorna erro quando o utilitário não
    # existe. Validar antes evita mensagens confusas no meio da análise.
    if command -v "$comando" >/dev/null 2>&1; then
        return 0
    fi

    error "Comando obrigatório não encontrado: ${comando}"
    exit 1
}

###############################################################################
# DESCOBRIR HOME REAL DO USUÁRIO
###############################################################################

get_user_home() {
    local entrada_passwd=''
    local nome=''
    local senha=''
    local uid=''
    local gid=''
    local gecos=''
    local home=''
    local shell=''

    # getent consulta a base de contas configurada no sistema. Isso é melhor do
    # que assumir /home/diogo, pois o home pode vir de LDAP, NIS ou outro backend.
    if entrada_passwd="$(getent passwd "$TARGET_USER")"; then
        IFS=':' read -r nome senha uid gid gecos home shell <<< "$entrada_passwd"
        if [[ -n "$nome" ]]; then
            if [[ -n "$home" ]]; then
                REAL_HOME="$home"
                API_FILE="${REAL_HOME}/${CONFIG_DIR_NAME}/${API_FILE_NAME}"
                return 0
            fi
        fi
    fi

    error "Não foi possível obter o home real de ${TARGET_USER} com getent."
    exit 1
}

###############################################################################
# VALIDAR NOMES PERMITIDOS
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

###############################################################################
# PARSER SEGURO DO FORMATO CONTROLADO
###############################################################################

parse_assignment_line() {
    local linha="$1"

    PARSED_NAME=''
    PARSED_VALUE=''

    # O formato aceito é exclusivamente NOME_VARIAVEL="valor".
    # Não há execução de código, não há expansão de comandos e não há leitura
    # direta com source. A expressão apenas separa nome e texto entre aspas.
    if [[ "$linha" =~ ^([A-Z][A-Z0-9_]*)=\"(.*)\"$ ]]; then
        PARSED_NAME="${BASH_REMATCH[1]}"
        PARSED_VALUE="${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

###############################################################################
# VALIDAR ARQUIVO E PERMISSÕES
###############################################################################

validate_file_security() {
    local permissao=''
    local proprietario=''
    local grupo=''

    if [[ ! -e "$API_FILE" ]]; then
        error "Arquivo não encontrado: ${API_FILE}"
        STATUS='INSEGURO'
        return 1
    fi

    if [[ -L "$API_FILE" ]]; then
        error "Arquivo recusado: links simbólicos não são permitidos."
        STATUS='INSEGURO'
        return 1
    fi

    if [[ ! -f "$API_FILE" ]]; then
        error "Arquivo recusado: o caminho não é um arquivo regular."
        STATUS='INSEGURO'
        return 1
    fi

    permissao="$(stat -c '%a' "$API_FILE")"
    proprietario="$(stat -c '%U' "$API_FILE")"
    grupo="$(stat -c '%G' "$API_FILE")"

    if [[ "$proprietario" != "$TARGET_USER" ]]; then
        error "Proprietário inseguro: esperado ${TARGET_USER}, encontrado ${proprietario}."
        STATUS='INSEGURO'
        return 1
    fi

    if [[ "$grupo" != "$TARGET_GROUP" ]]; then
        error "Grupo inseguro: esperado ${TARGET_GROUP}, encontrado ${grupo}."
        STATUS='INSEGURO'
        return 1
    fi

    if [[ "$permissao" != '600' ]]; then
        error "Permissão insegura: esperado 600, encontrado ${permissao}."
        STATUS='INSEGURO'
        return 1
    fi

    success "Arquivo, proprietário e permissões estão seguros."
    return 0
}

###############################################################################
# VALIDAR CONTEÚDO SEM MOSTRAR VALORES
###############################################################################

validate_content() {
    local linha=''
    local numero_linha=0
    local nomes_vistos=' '
    local nome_esperado=''
    local encontrado=0
    local valor=''

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
                        warning "Variável duplicada na linha ${numero_linha}: ${PARSED_NAME}"
                        DUPLICATE_LINES=$((DUPLICATE_LINES + 1))
                        STATUS='INSEGURO'
                        ;;
                    *)
                        nomes_vistos="${nomes_vistos}${PARSED_NAME} "
                        ;;
                esac
            else
                warning "Variável não autorizada na linha ${numero_linha}: ${PARSED_NAME}"
                INVALID_LINES=$((INVALID_LINES + 1))
                STATUS='INSEGURO'
            fi
        else
            warning "Linha inválida detectada sem exibir conteúdo: ${numero_linha}"
            INVALID_LINES=$((INVALID_LINES + 1))
            STATUS='INSEGURO'
        fi
    done < "$API_FILE"

    for nome_esperado in "${API_VARIABLES[@]}"; do
        encontrado=0
        valor=''

        while IFS= read -r linha; do
            if parse_assignment_line "$linha"; then
                if [[ "$PARSED_NAME" == "$nome_esperado" ]]; then
                    encontrado=1
                    valor="$PARSED_VALUE"
                    break
                fi
            fi
        done < "$API_FILE"

        if [[ "$encontrado" -eq 1 ]]; then
            if [[ -n "$valor" ]]; then
                success "${nome_esperado} está configurada."
                CONFIGURED_COUNT=$((CONFIGURED_COUNT + 1))
            else
                warning "${nome_esperado} não está configurada."
                MISSING_COUNT=$((MISSING_COUNT + 1))
            fi
        else
            warning "${nome_esperado} está ausente no arquivo."
            MISSING_COUNT=$((MISSING_COUNT + 1))
            STATUS='INSEGURO'
        fi
    done
}

###############################################################################
# RESUMO FINAL
###############################################################################

print_summary() {
    local permissao='indisponível'
    local proprietario='indisponível'

    if [[ -f "$API_FILE" ]]; then
        if [[ ! -L "$API_FILE" ]]; then
            permissao="$(stat -c '%a' "$API_FILE")"
            proprietario="$(stat -c '%U' "$API_FILE")"
        fi
    fi

    printf '\n'
    printf '%s\n' 'Resumo:'
    printf '\n'
    printf 'APIs cadastradas.....: %s\n' "$CONFIGURED_COUNT"
    printf 'APIs ausentes........: %s\n' "$MISSING_COUNT"
    printf 'Arquivo..............: %s\n' "$API_FILE"
    printf 'Permissão............: %s\n' "$permissao"
    printf 'Proprietário.........: %s\n' "$proprietario"
    printf 'Status...............: %s\n' "$STATUS"
}

main() {
    local argumento=''

    for argumento in "$@"; do
        if [[ "$argumento" == "$FUTURE_ONLINE_FLAG" ]]; then
            warning "O modo --online está reservado para versão futura e não será executado agora."
        else
            error "Argumento não reconhecido: ${argumento}"
            exit 1
        fi
    done

    require_command getent
    require_command stat

    get_user_home
    validate_file_security
    validate_content
    print_summary

    if [[ "$STATUS" != 'SEGURO' ]]; then
        exit 1
    fi
}

main "$@"
