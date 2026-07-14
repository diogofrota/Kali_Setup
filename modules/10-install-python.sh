#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 10
# NOME..........: Instalação de Python e ferramentas pipx
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Preparar o runtime Python profissional com python3, venv, headers de
# desenvolvimento e pipx, instalando ferramentas Python isoladas conforme o
# inventário config/tools-python.txt.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida que o sistema é Kali Linux.
# 3. Instala python3, python3-venv, python3-dev e pipx.
# 4. Cria ~/.virtualenvs com permissão restritiva.
# 5. Executa pipx ensurepath como usuário real.
# 6. Instala ferramentas via apt ou pipx conforme inventário.
# 7. Pergunta antes de ferramentas opcionais.
#
# RISCOS CONTROLADOS
#
# O módulo não usa sudo pip install nem instala pacotes Python diretamente no
# Python global do sistema. Ferramentas pipx ficam isoladas por usuário.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='10-install-python'
NEXT_MODULE='11-install-go.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/tools-python.txt"

# shellcheck source=../lib/common.sh
source "${PROJECT_ROOT}/lib/common.sh"

trap 'kali_setup_handle_error; exit $?' ERR

INSTALLED=0
EXISTING=0
SKIPPED=0
FAILED=0
LOG_FILE=''
REAL_USER=''
REAL_HOME=''

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 10' \
        '                 Python e pipx' \
        '============================================================'
}

install_python_runtime() {
    local pacote=''

    for pacote in python3 python3-venv python3-dev pipx; do
        if apt_package_installed "$pacote"; then
            EXISTING=$((EXISTING + 1))
        else
            if apt_package_exists "$pacote"; then
                apt install "$pacote"
                INSTALLED=$((INSTALLED + 1))
            else
                warning "Pacote não encontrado: ${pacote}"
                FAILED=$((FAILED + 1))
            fi
        fi
    done
}

process_python_tools() {
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

        if [[ "$prioridade" == 'OPTIONAL' ]]; then
            if confirm_action "Instalar ferramenta Python opcional ${nome}?"; then
                :
            else
                SKIPPED=$((SKIPPED + 1))
                continue
            fi
        fi

        if [[ "$metodo" == 'apt' ]]; then
            if apt_package_installed "$origem"; then
                EXISTING=$((EXISTING + 1))
            else
                if apt_package_exists "$origem"; then
                    apt install "$origem"
                    INSTALLED=$((INSTALLED + 1))
                else
                    warning "Pacote Python via apt ausente: ${origem}"
                    SKIPPED=$((SKIPPED + 1))
                fi
            fi
        fi

        if [[ "$metodo" == 'pipx' ]]; then
            if command_exists pipx; then
                run_as_real_user "$REAL_USER" pipx install "$origem"
                INSTALLED=$((INSTALLED + 1))
            else
                warning "pipx ausente; ${nome} ignorado."
                SKIPPED=$((SKIPPED + 1))
            fi
        fi
    done 9< "$CONFIG_FILE"
}

main() {
    print_banner
    require_root
    require_commands apt apt-cache dpkg-query getent sudo mkdir
    detect_kali
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    install_python_runtime
    ensure_directory "${REAL_HOME}/.virtualenvs" '700' "$REAL_USER" "$REAL_USER"

    if command_exists pipx; then
        run_as_real_user "$REAL_USER" pipx ensurepath
    else
        warning "pipx não está disponível; ferramentas pipx serão ignoradas."
        SKIPPED=$((SKIPPED + 1))
    fi

    process_python_tools

    warning "sudo pip install e pip global do sistema não são usados."
    print_summary_line 'Instaladas' "$INSTALLED"
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
