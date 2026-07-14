#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 07
# NOME..........: Criação de diretórios profissionais
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Criar uma estrutura organizada no home do usuário real para projetos,
# relatórios, evidências, wordlists, payloads, laboratórios, ferramentas e
# arquivos temporários de trabalho.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Descobre o usuário real e o home correto.
# 3. Cria cada diretório esperado quando ele ainda não existe.
# 4. Ajusta proprietário e grupo para o usuário real.
# 5. Aplica permissão 750 por padrão e 700 para diretórios sensíveis.
# 6. Recusa links simbólicos para evitar sobrescrita de caminhos inesperados.
#
# RISCOS CONTROLADOS
#
# Diretórios como Clients, Evidence e Backups podem conter dados sensíveis. Por
# isso recebem permissão 700. O módulo não copia dados reais para o repositório.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='07-create-directories'
NEXT_MODULE='08-configure-shell.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
TEMPLATE_DIR="${PROJECT_ROOT}/config/engagement-template"

# shellcheck source=../lib/common.sh
source "${PROJECT_ROOT}/lib/common.sh"

trap 'kali_setup_handle_error; exit $?' ERR

CREATED=0
EXISTING=0
SKIPPED=0
FAILED=0
LOG_FILE=''
REAL_USER=''
REAL_HOME=''

DIRECTORIES=(Labs Projects Scripts Tools Git Reports Clients Notes Wordlists Payloads Docker Captures Evidence Screenshots Engagements Templates Backups Temp Logs)
PRIVATE_DIRECTORIES=(Clients Evidence Backups)

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 07' \
        '            Diretórios Profissionais' \
        '============================================================'
}

is_private_dir() {
    local nome="$1"
    local item=''

    for item in "${PRIVATE_DIRECTORIES[@]}"; do
        if [[ "$item" == "$nome" ]]; then
            return 0
        fi
    done

    return 1
}

create_user_directory() {
    local nome="$1"
    local caminho="${REAL_HOME}/${nome}"
    local modo='750'

    if is_private_dir "$nome"; then
        modo='700'
    fi

    if [[ -L "$caminho" ]]; then
        warning "Link simbólico recusado: ${caminho}"
        FAILED=$((FAILED + 1))
        return 0
    fi

    if [[ -d "$caminho" ]]; then
        EXISTING=$((EXISTING + 1))
    else
        mkdir -p -- "$caminho"
        CREATED=$((CREATED + 1))
    fi

    chown "${REAL_USER}:${REAL_USER}" "$caminho"
    chmod "$modo" "$caminho"
}

main() {
    local dir=''

    print_banner
    require_root
    require_commands getent chown chmod mkdir cp
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    for dir in "${DIRECTORIES[@]}"; do
        create_user_directory "$dir"
    done

    info "Template de engagement mantido no repositório: ${TEMPLATE_DIR}"
    info "Não foi criada pasta real com dados fictícios de cliente."

    print_summary_line 'Instaladas' "$CREATED"
    print_summary_line 'Já existentes' "$EXISTING"
    print_summary_line 'Atualizadas' '0'
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' '0'
    print_summary_line 'Falhas' "$FAILED"
    print_summary_line 'Log' "$LOG_FILE"
    print_summary_line 'Status' 'OK'
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"
}

main "$@"
