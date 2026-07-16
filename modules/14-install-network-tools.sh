#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 14
# NOME..........: Instalação de ferramentas de rede
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Instalar ferramentas de rede, enumeração, captura, DNS, SMB, SNMP, TLS, LDAP
# e clientes de banco de dados a partir do inventário config/packages-network.txt.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida que o sistema é Kali Linux.
# 3. Lê o inventário de ferramentas de rede linha por linha.
# 4. Instala ferramentas CORE, RECOMMENDED e OPTIONAL via APT.
# 5. Pergunta antes de configurar captura Wireshark para usuários não root.
#
# RISCOS CONTROLADOS
#
# Ferramentas de rede podem afetar ambientes se usadas sem escopo. O módulo
# apenas instala pacotes e não executa varreduras. Configuração de captura sem
# root também exige confirmação explícita.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='14-install-network-tools'
NEXT_MODULE='15-install-recon-tools.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/packages-network.txt"

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
        '            KALI SETUP - MÓDULO 14' \
        '              Ferramentas de Rede' \
        '============================================================'
}

install_network_package() {
    local pacote="$1"
    local prioridade="$2"

    if apt_package_installed "$pacote"; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${pacote}"
        return 0
    fi

    if apt_package_exists "$pacote"; then
        case "$prioridade" in
            CORE|RECOMMENDED|OPTIONAL)
                apt-get install -y -- "$pacote"
                INSTALLED=$((INSTALLED + 1))
                ;;
            *)
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

    # Mantém o inventário separado da entrada interativa do terminal.
    while IFS= read -r -u 9 linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi
        if [[ "$linha" == \#* ]]; then
            continue
        fi

        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        if [[ -z "${arquitetura:-}" ]]; then
            FAILED=$((FAILED + 1))
            continue
        fi

        if [[ "$metodo" == 'apt' ]]; then
            install_network_package "$origem" "$prioridade"
        fi
    done 9< "$CONFIG_FILE"
}

configure_wireshark_capture() {
    if command_exists dumpcap; then
        success "dumpcap encontrado."
    else
        return 0
    fi

    warning "Permitir captura para usuários não root altera permissões de captura."
    if confirm_action 'Configurar wireshark-common para captura por usuários não root?'; then
        dpkg-reconfigure wireshark-common
        UPDATED=$((UPDATED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
}

main() {
    print_banner
    require_root
    require_commands apt-get apt-cache dpkg-query dpkg-reconfigure getent
    detect_kali
    REAL_USER="$(get_real_user)"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    process_inventory
    configure_wireshark_capture

    print_summary_line 'Instaladas' "$INSTALLED"
    print_summary_line 'Já existentes' "$EXISTING"
    print_summary_line 'Atualizadas' "$UPDATED"
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' "$INCOMPATIBLE"
    print_summary_line 'Falhas' "$FAILED"
    print_summary_line 'Log' "$LOG_FILE"
    print_summary_line 'Status' "OK ($(detect_architecture))"
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"
}

main "$@"
