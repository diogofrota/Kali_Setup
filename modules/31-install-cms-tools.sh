#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 31
# NOME..........: Instalação de ferramentas para auditoria de CMS
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Instalar ferramentas de identificação, enumeração e avaliação de segurança de
# CMS para pentests profissionais realizados em escopos autorizados.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos e valida o Kali Linux.
# 2. Lê config/31-packages-cms.txt e valida cada registro.
# 3. Instala itens CORE, RECOMMENDED e OPTIONAL disponíveis via APT.
# 4. Registra pacotes ausentes ou falhas isoladas e continua a instalação.
# 5. Não atualiza bases, consulta alvos nem executa qualquer varredura.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='31-install-cms-tools'
NEXT_MODULE='32-install-api-tools.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/31-packages-cms.txt"

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
        '            KALI SETUP - MÓDULO 31' \
        '          Ferramentas para Auditoria de CMS' \
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

priority_is_enabled() {
    case "$1" in
        CORE|RECOMMENDED|OPTIONAL) return 0 ;;
        *) return 1 ;;
    esac
}

install_apt_tool() {
    local nome="$1"
    local prioridade="$2"
    local pacote="$3"

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

        if [[ -z "$nome" || -z "$categoria" || -z "$prioridade" || -z "$metodo" ||
              -z "$origem" || -z "$validacao" || -z "$arquitetura" ]]; then
            record_failure 'registro inválido em 31-packages-cms.txt'
            continue
        fi
        if ! priority_is_enabled "$prioridade"; then
            warning "Prioridade não instalável para ${nome}: ${prioridade}."
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        case "$metodo" in
            apt) install_apt_tool "$nome" "$prioridade" "$origem" ;;
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

    warning 'As ferramentas foram somente instaladas; nenhuma base foi atualizada e nenhum alvo foi consultado.'
    warning 'Use exclusivamente em sistemas próprios ou com autorização formal e escopo definido.'
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
