#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 06
# NOME..........: Instalação de pacotes base
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Instalar utilitários essenciais de administração, terminal, rede básica,
# compilação, Python e qualidade de código a partir do inventário
# config/packages-base.txt.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida que o sistema é Kali Linux.
# 3. Lê o inventário de pacotes base linha por linha.
# 4. Instala pacotes CORE, RECOMMENDED e OPTIONAL quando ausentes.
# 5. Ignora linhas inválidas e registra contadores no resumo.
#
# RISCOS CONTROLADOS
#
# O módulo não instala metapacotes gigantes como kali-linux-everything. Cada
# pacote é validado no apt-cache antes da instalação.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='06-base-packages'
NEXT_MODULE='07-create-directories.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/packages-base.txt"

# shellcheck source=../lib/common.sh
source "${PROJECT_ROOT}/lib/common.sh"

trap 'kali_setup_handle_error; exit $?' ERR

INSTALLED=0
EXISTING=0
UPDATED=0
SKIPPED=0
INCOMPATIBLE=0
FAILED=0
LOG_FILE=''
REAL_USER=''

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 06' \
        '                 Pacotes Base' \
        '============================================================'
}

install_package() {
    local pacote="$1"
    local prioridade="$2"

    if apt_package_installed "$pacote"; then
        success "Já instalado: ${pacote}"
        EXISTING=$((EXISTING + 1))
        return 0
    fi

    if apt_package_exists "$pacote"; then
        case "$prioridade" in
            CORE|RECOMMENDED|OPTIONAL)
                info "Instalando pacote ${prioridade}: ${pacote}"
                apt-get install -y -- "$pacote"
                INSTALLED=$((INSTALLED + 1))
                ;;
            *)
                warning "Prioridade desconhecida para ${pacote}; ignorado."
                SKIPPED=$((SKIPPED + 1))
                ;;
        esac
    else
        warning "Pacote ausente no apt-cache: ${pacote}"
        SKIPPED=$((SKIPPED + 1))
    fi
}

process_inventory() {
    local linha=''
    local nome=''
    local categoria=''
    local prioridade=''
    local metodo=''
    local origem=''
    local validacao=''
    local arquitetura=''

    # O inventário usa um descritor próprio para não ocupar a entrada padrão.
    while IFS= read -r -u 9 linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi
        if [[ "$linha" == \#* ]]; then
            continue
        fi

        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        if [[ -z "${arquitetura:-}" ]]; then
            warning "Linha inválida ignorada em packages-base.txt."
            FAILED=$((FAILED + 1))
            continue
        fi

        if [[ "$metodo" == 'apt' ]]; then
            install_package "$origem" "$prioridade"
        fi
    done 9< "$CONFIG_FILE"
}

main() {
    print_banner
    require_root
    require_commands apt-get apt-cache dpkg-query date uname
    detect_kali
    REAL_USER="$(get_real_user)"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    info "Metapacotes grandes como kali-linux-everything não são instalados por este módulo."
    process_inventory

    print_summary_line 'Instaladas' "$INSTALLED"
    print_summary_line 'Já existentes' "$EXISTING"
    print_summary_line 'Atualizadas' "$UPDATED"
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' "$INCOMPATIBLE"
    print_summary_line 'Falhas' "$FAILED"
    print_summary_line 'Log' "$LOG_FILE"
    print_summary_line 'Status' 'OK'
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"
}

main "$@"
