#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 09
# NOME..........: Configuração do Git
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Configurar preferências globais do Git para o usuário real e reforçar proteção
# contra commits acidentais de secrets por meio de um gitignore global.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Descobre usuário e home reais.
# 3. Solicita nome e e-mail do Git.
# 4. Define main como branch inicial padrão.
# 5. Pergunta sobre pull.rebase, editor e credential.helper cache.
# 6. Cria ou atualiza ~/.gitignore_global.
# 7. Configura core.excludesfile apontando para esse arquivo.
#
# RISCOS CONTROLADOS
#
# Credenciais e chaves privadas não devem entrar em repositórios. O módulo evita
# credential.helper store por padrão e adiciona padrões de secrets ao gitignore
# global.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='09-configure-git'
NEXT_MODULE='10-install-python.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"

# shellcheck source=../lib/common.sh
source "${PROJECT_ROOT}/lib/common.sh"

trap 'kali_setup_handle_error; exit $?' ERR

UPDATED=0
SKIPPED=0
LOG_FILE=''
REAL_USER=''
REAL_HOME=''

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 09' \
        '                Configuração do Git' \
        '============================================================'
}

git_as_user() {
    run_as_real_user "$REAL_USER" git "$@"
}

configure_gitignore_global() {
    local arquivo="${REAL_HOME}/.gitignore_global"

    if [[ -L "$arquivo" ]]; then
        die "gitignore global é link simbólico; recusado."
    fi

    if [[ ! -e "$arquivo" ]]; then
        : > "$arquivo"
        chown "${REAL_USER}:${REAL_USER}" "$arquivo"
        chmod 600 "$arquivo"
    fi

    if grep -Fq 'api-keys.env' "$arquivo"; then
        :
    else
        printf '\n# KALI SETUP - secrets locais\n' >> "$arquivo"
        printf '.env\n.env.*\napi-keys.env\nprovider-config.yaml\n*.pem\n*.key\n*.kdbx\n' >> "$arquivo"
    fi

    git_as_user config --global core.excludesfile "$arquivo"
    UPDATED=$((UPDATED + 1))
}

main() {
    local nome=''
    local email=''
    local editor=''

    print_banner
    require_root
    require_commands git getent sudo grep
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    printf 'Nome para git user.name: '
    read -r nome
    if [[ -n "$nome" ]]; then
        git_as_user config --global user.name "$nome"
        UPDATED=$((UPDATED + 1))
    else
        warning "Nome não informado; user.name não alterado."
        SKIPPED=$((SKIPPED + 1))
    fi

    printf 'E-mail para git user.email: '
    read -r email
    if [[ -n "$email" ]]; then
        git_as_user config --global user.email "$email"
        UPDATED=$((UPDATED + 1))
    else
        warning "E-mail não informado; user.email não alterado."
        SKIPPED=$((SKIPPED + 1))
    fi

    git_as_user config --global init.defaultBranch main

    if confirm_action 'Configurar pull.rebase=false?'; then
        git_as_user config --global pull.rebase false
        UPDATED=$((UPDATED + 1))
    fi

    printf 'Editor Git (ex: vim, nano, code --wait): '
    read -r editor
    if [[ -n "$editor" ]]; then
        git_as_user config --global core.editor "$editor"
        UPDATED=$((UPDATED + 1))
    fi

    if confirm_action 'Configurar credential.helper cache?'; then
        git_as_user config --global credential.helper cache
        UPDATED=$((UPDATED + 1))
    else
        warning "credential.helper store não será usado por padrão."
        SKIPPED=$((SKIPPED + 1))
    fi

    configure_gitignore_global
    git_as_user config --global --list

    print_summary_line 'Instaladas' '0'
    print_summary_line 'Já existentes' '0'
    print_summary_line 'Atualizadas' "$UPDATED"
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' '0'
    print_summary_line 'Falhas' '0'
    print_summary_line 'Log' "$LOG_FILE"
    print_summary_line 'Status' 'OK'
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"
}

main "$@"
