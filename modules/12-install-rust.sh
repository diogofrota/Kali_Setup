#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 12
# NOME..........: Instalação de Rust e Cargo
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Preparar o ambiente Rust/Cargo para ferramentas que dependem desse ecossistema
# e instalar ferramentas opcionais somente com confirmação do operador.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida que o sistema é Kali Linux.
# 3. Cria ~/.cargo/bin com dono e permissões corretas.
# 4. Instala cargo e rustc via APT quando disponíveis.
# 5. Pergunta antes de instalar ferramentas Rust opcionais.
# 6. Mantém ferramentas não validadas fora do fluxo automático.
#
# RISCOS CONTROLADOS
#
# O módulo não executa instaladores remotos como rustup automaticamente. Cada
# ferramenta instalada via cargo exige confirmação e ferramentas sem validação
# de manutenção permanecem desabilitadas.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='12-install-rust'
NEXT_MODULE='13-install-docker.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"

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
        '            KALI SETUP - MÓDULO 12' \
        '                  Rust e Cargo' \
        '============================================================'
}

install_rust_runtime() {
    if command_exists cargo; then
        EXISTING=$((EXISTING + 1))
        success "Cargo já está instalado."
        return 0
    fi

    if apt_package_exists cargo; then
        apt install cargo rustc
        INSTALLED=$((INSTALLED + 1))
    else
        warning "Pacote cargo não encontrado. rustup remoto não será executado automaticamente."
        SKIPPED=$((SKIPPED + 1))
    fi
}

maybe_install_rust_tool() {
    local pacote="$1"
    local comando="$2"

    if command_exists "$comando"; then
        EXISTING=$((EXISTING + 1))
        return 0
    fi

    if confirm_action "Instalar ferramenta Rust opcional ${pacote} via cargo?"; then
        run_as_real_user "$REAL_USER" cargo install "$pacote"
        INSTALLED=$((INSTALLED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
}

main() {
    print_banner
    require_root
    require_commands apt apt-cache dpkg-query getent sudo mkdir
    detect_kali
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    ensure_directory "${REAL_HOME}/.cargo/bin" '700' "$REAL_USER" "$REAL_USER"
    install_rust_runtime

    if command_exists cargo; then
        maybe_install_rust_tool feroxbuster feroxbuster
        maybe_install_rust_tool rustscan rustscan
    fi

    warning "ripgen e rusthound-ce permanecem desabilitados até nova verificação de manutenção."
    print_summary_line 'Instaladas' "$INSTALLED"
    print_summary_line 'Já existentes' "$EXISTING"
    print_summary_line 'Atualizadas' '0'
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' '0'
    print_summary_line 'Falhas' "$FAILED"
    print_summary_line 'Log' "$LOG_FILE"
    print_summary_line 'Status' "OK ($(detect_architecture))"
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"
}

main "$@"
