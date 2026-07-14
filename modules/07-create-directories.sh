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
# LOCAL DE CRIAÇÃO
#
# Todos os diretórios são criados diretamente no home do usuário real,
# detectado mesmo quando o módulo é executado com sudo:
#
#   ${REAL_HOME}/
#
# Exemplo usando sudo como diogo: /home/diogo/. Se o módulo for executado
# diretamente em uma sessão root, sem SUDO_USER, o home real será /root.
#
# ÁRVORE CRIADA
#
# ${REAL_HOME}/
# ├── Labs/          (750)
# ├── Projects/      (750)
# ├── Scripts/       (750)
# ├── Tools/         (750)
# ├── Git/           (750)
# ├── Reports/       (750)
# ├── Clients/       (700 - privado)
# ├── Notes/         (750)
# ├── Wordlists/     (750)
# ├── Payloads/      (750)
# ├── Docker/        (750)
# ├── Captures/      (750)
# ├── Evidence/      (700 - privado)
# ├── Screenshots/   (750)
# ├── Engagements/   (750)
# ├── Templates/     (750)
# ├── Backups/       (700 - privado)
# ├── Temp/          (750)
# └── Logs/          (750)
#
# Cada diretório pertence a ${REAL_USER}:${REAL_USER}. Diretórios que já existem
# também recebem novamente o proprietário e a permissão definidos acima.
#
# LOG TÉCNICO DA EXECUÇÃO
#
# Além da árvore principal, start_log mantém o log privado do módulo em:
#
# ${REAL_HOME}/.local/state/kali-setup/logs/                       (700)
# └── 07-create-directories-AAAAMMDD-HHMMSS.log                   (600)
#
# O template de engagement permanece em config/engagement-template e não é
# copiado automaticamente para o home.
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
