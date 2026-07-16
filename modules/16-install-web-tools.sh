#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 16
# NOME..........: Instalação de ferramentas Web
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Instalar proxies, fuzzers, enumeradores, scanners Web e navegadores usados em
# avaliações autorizadas, a partir de config/16-packages-web.txt.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos e valida o Kali Linux.
# 2. Lê o inventário Web e valida cada registro.
# 3. Instala automaticamente itens CORE, RECOMMENDED e OPTIONAL via APT.
# 4. Detecta pacotes já instalados e continua após falhas isoladas.
# 5. Não inicia navegadores, proxies, listeners ou varreduras.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='16-install-web-tools'
NEXT_MODULE='17-install-vulnerability-tools.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/16-packages-web.txt"

# shellcheck source=../lib/common.sh
source "${PROJECT_ROOT}/lib/common.sh"

trap 'kali_setup_handle_error; exit $?' ERR

INSTALLED=0
EXISTING=0
SKIPPED=0
FAILED=0
LOG_FILE=''
declare -a INSTALLED_ITEMS=()
declare -a FAILED_ITEMS=()

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 16' \
        '                Ferramentas Web' \
        '============================================================'
}

record_installed() {
    INSTALLED=$((INSTALLED + 1))
    INSTALLED_ITEMS+=("$1")
    success "Instalado: $1"
}

record_failure() {
    FAILED=$((FAILED + 1))
    FAILED_ITEMS+=("$1")
    error "Falha: $1. O módulo continuará."
}

print_result_list() {
    local titulo="$1"
    local item=''
    shift
    printf '\n%s\n' "$titulo"
    if [[ "$#" -eq 0 ]]; then
        printf '  - Nenhum.\n'
        return 0
    fi
    for item in "$@"; do
        printf '  - %s\n' "$item"
    done
}

install_web_package() {
    local nome="$1"
    local prioridade="$2"
    local pacote="$3"

    case "$prioridade" in
        CORE|RECOMMENDED|OPTIONAL) ;;
        *)
            warning "Prioridade desconhecida para ${nome}: ${prioridade}."
            SKIPPED=$((SKIPPED + 1))
            return 0
            ;;
    esac

    if apt_package_installed "$pacote"; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${nome} (${pacote})"
    elif apt_package_exists "$pacote"; then
        info "Instalando ${nome} (${prioridade}) via APT."
        if apt-get install -y -- "$pacote"; then
            record_installed "${nome} (APT: ${pacote})"
        else
            record_failure "${nome} (APT: ${pacote})"
        fi
    else
        record_failure "${nome} (pacote APT ausente: ${pacote})"
    fi
}

process_inventory() {
    local linha='' nome='' categoria='' prioridade=''
    local metodo='' origem='' validacao='' arquitetura=''

    while IFS= read -r linha; do
        [[ -z "$linha" || "$linha" == \#* ]] && continue
        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        if [[ -z "$nome" || -z "$prioridade" || -z "$metodo" || -z "$origem" || -z "$arquitetura" ]]; then
            record_failure 'registro inválido em 16-packages-web.txt'
            continue
        fi

        case "$metodo" in
            apt) install_web_package "$nome" "$prioridade" "$origem" ;;
            *)
                warning "Método não suportado para ${nome}: ${metodo}."
                SKIPPED=$((SKIPPED + 1))
                ;;
        esac
    done < "$CONFIG_FILE"
}

main() {
    print_banner
    require_root
    require_commands apt-get apt-cache dpkg-query getent
    detect_kali
    validate_regular_file "$CONFIG_FILE"
    LOG_FILE="$(start_log "$(get_real_user)" "$MODULE_NAME")"

    process_inventory

    warning 'As ferramentas foram somente instaladas; nenhuma varredura ou listener foi iniciado.'
    print_summary_line 'Instaladas' "$INSTALLED"
    print_summary_line 'Já existentes' "$EXISTING"
    print_summary_line 'Atualizadas' '0'
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' '0'
    print_summary_line 'Falhas' "$FAILED"
    print_summary_line 'Log' "$LOG_FILE"
    if [[ "$FAILED" -eq 0 ]]; then
        print_summary_line 'Status' "OK ($(detect_architecture))"
    else
        print_summary_line 'Status' "PARCIAL ($(detect_architecture))"
    fi
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"
    print_result_list 'Instalado nesta execução:' "${INSTALLED_ITEMS[@]}"
    print_result_list 'Falhas nesta execução:' "${FAILED_ITEMS[@]}"
}

main "$@"
