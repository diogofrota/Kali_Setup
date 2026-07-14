#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# SCRIPT........: edit-api-keys
# NOME..........: Editor seguro de chaves de API
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO......: Abrir o arquivo real de chaves em um editor local seguro
#
# O script valida o arquivo antes de abrir, não imprime secrets, não cria backup
# em texto puro e corrige proprietário e permissão depois da edição.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma que o utilitário está sendo executado pelo usuário alvo.
# 2. Localiza ~/.config/kali-setup/api-keys.env.
# 3. Valida diretório, arquivo, dono, grupo e permissões.
# 4. Abre o editor definido em EDITOR ou nano por padrão.
# 5. Reaplica permissão 600 após a edição.
#
# RISCOS CONTROLADOS
#
# O script recusa links simbólicos, não aceita EDITOR com argumentos embutidos e
# não imprime o conteúdo do arquivo em nenhum momento.
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
    error "O editor de chaves encontrou um erro."
    error "Comando executado: ${comando_falhou}"
    error "Linha aproximada: ${linha_aproximada}"
    error "Código de saída: ${codigo_saida}"
    printf '\n' >&2

    exit "$codigo_saida"
}

trap handle_error ERR

REAL_HOME=''
API_DIR=''
API_FILE=''
CURRENT_USER=''

require_command() {
    local comando="$1"

    if command -v "$comando" >/dev/null 2>&1; then
        return 0
    fi

    error "Comando obrigatório não encontrado: ${comando}"
    exit 1
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
            API_DIR="${REAL_HOME}/${CONFIG_DIR_NAME}"
            API_FILE="${API_DIR}/${API_FILE_NAME}"
            return 0
        fi
    fi

    error "Não foi possível obter o home real de ${TARGET_USER}."
    exit 1
}

validate_secure_path() {
    local caminho="$1"
    local tipo="$2"

    if [[ -L "$caminho" ]]; then
        error "${tipo} recusado: links simbólicos não são permitidos."
        exit 1
    fi

    if [[ "$tipo" == 'Diretório' ]]; then
        if [[ ! -d "$caminho" ]]; then
            error "Diretório não encontrado: ${caminho}"
            exit 1
        fi
    else
        if [[ ! -f "$caminho" ]]; then
            error "Arquivo não encontrado ou não regular: ${caminho}"
            exit 1
        fi
    fi
}

validate_security() {
    local file_mode=''
    local dir_mode=''
    local file_owner=''
    local file_group=''
    local dir_owner=''
    local dir_group=''

    validate_secure_path "$API_DIR" 'Diretório'
    validate_secure_path "$API_FILE" 'Arquivo'

    dir_mode="$(stat -c '%a' "$API_DIR")"
    dir_owner="$(stat -c '%U' "$API_DIR")"
    dir_group="$(stat -c '%G' "$API_DIR")"

    if [[ "$dir_owner" != "$CURRENT_USER" ]]; then
        error "Proprietário inseguro do diretório: ${dir_owner}"
        exit 1
    fi

    if [[ "$dir_group" != "$TARGET_GROUP" ]]; then
        error "Grupo inseguro do diretório: ${dir_group}"
        exit 1
    fi

    if [[ "$dir_mode" != '700' ]]; then
        error "Permissão insegura no diretório: ${dir_mode}"
        exit 1
    fi

    file_mode="$(stat -c '%a' "$API_FILE")"
    file_owner="$(stat -c '%U' "$API_FILE")"
    file_group="$(stat -c '%G' "$API_FILE")"

    if [[ "$file_owner" != "$CURRENT_USER" ]]; then
        error "Proprietário inseguro do arquivo: ${file_owner}"
        exit 1
    fi

    if [[ "$file_group" != "$TARGET_GROUP" ]]; then
        error "Grupo inseguro do arquivo: ${file_group}"
        exit 1
    fi

    if [[ "$file_mode" != '600' ]]; then
        error "Permissão insegura no arquivo: ${file_mode}"
        exit 1
    fi
}

open_editor() {
    local editor_command="${EDITOR:-nano}"

    # Não aceitamos argumentos dentro de EDITOR porque interpretar uma linha de
    # comando exigiria parsing extra. O usuário pode definir EDITOR para um
    # executável simples, como nano, vim, nvim ou micro.
    if [[ "$editor_command" == *' '* ]]; then
        error "A variável EDITOR deve conter apenas o nome do executável."
        exit 1
    fi

    require_command "$editor_command"

    info "Abrindo arquivo de chaves no editor configurado."
    "$editor_command" "$API_FILE"
}

repair_security_after_edit() {
    chmod 600 "$API_FILE"
    success "Arquivo editado. Permissão 600 conferida sem exibir chaves."
}

validate_current_user() {
    CURRENT_USER="$(id -un)"

    if [[ "$CURRENT_USER" != "$TARGET_USER" ]]; then
        error "Este utilitário deve ser executado pelo usuário ${TARGET_USER}."
        exit 1
    fi
}

main() {
    require_command getent
    require_command stat
    require_command chmod
    require_command id

    validate_current_user
    get_user_home
    validate_security
    open_editor
    repair_security_after_edit
}

main "$@"
