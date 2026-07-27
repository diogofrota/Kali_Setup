#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 33
# NOME..........: Instalação de ferramentas para testes de carga
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Preparar uma workstation profissional para testes autorizados de carga,
# desempenho, estresse, pico, resistência e protocolos HTTP/1.1 e HTTP/2.
#
# RISCOS CONTROLADOS
#
# O módulo somente instala ferramentas. Não inicia testes, não altera limites
# do kernel e não envia requisições. Testes de carga podem causar indisponibilidade
# e só devem ocorrer com autorização, janela, limites e plano de interrupção.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='33-install-load-testing-tools'
NEXT_MODULE='Nenhum'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/33-tools-load-testing.txt"
K6_SOURCE_FILE="${PROJECT_ROOT}/assets/k6.list"
GATLING_LAUNCHER="${PROJECT_ROOT}/assets/gatling"

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
declare -a INSTALLED_ITEMS=()
declare -a FAILED_ITEMS=()

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 33' \
        '             Testes de carga e desempenho' \
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

command_is_available() {
    local comando="$1"
    command_exists "$comando" || [[ -x "${REAL_HOME}/.local/bin/${comando}" ]] ||
        [[ -x "${REAL_HOME}/go/bin/${comando}" ]]
}

install_apt_tool() {
    local nome="$1"
    local pacote="$2"
    local comando="$3"

    if command_is_available "$comando" || apt_package_installed "$pacote"; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${nome}"
    elif apt_package_exists "$pacote"; then
        info "Instalando ${nome} via APT."
        if apt-get install -y -- "$pacote"; then
            record_installed "${nome} (APT: ${pacote})"
        else
            record_failure "${nome} (APT: ${pacote})"
        fi
    else
        record_failure "${nome} (pacote APT ausente: ${pacote})"
    fi
}

install_pipx_tool() {
    local nome="$1"
    local origem="$2"
    local comando="$3"

    if command_is_available "$comando"; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${nome}"
    elif ! command_exists pipx; then
        record_failure "${nome} (pipx ausente; execute primeiro o módulo 10)"
    elif run_as_real_user "$REAL_USER" env HOME="$REAL_HOME" pipx install "$origem"; then
        record_installed "${nome} (pipx)"
    else
        record_failure "${nome} (pipx: ${origem})"
    fi
}

install_go_tool() {
    local nome="$1"
    local origem="$2"
    local comando="$3"

    if command_is_available "$comando"; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${nome}"
    elif ! command_exists go; then
        record_failure "${nome} (Go ausente; execute primeiro o módulo 11)"
    elif run_as_real_user "$REAL_USER" env HOME="$REAL_HOME" \
        GOPATH="${REAL_HOME}/go" GOBIN="${REAL_HOME}/go/bin" go install "$origem"; then
        record_installed "${nome} (Go)"
    else
        record_failure "${nome} (Go: ${origem})"
    fi
}

install_k6() {
    local nome="$1"
    local chave_temporaria=''

    if command_is_available k6; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${nome}"
        return 0
    fi
    if ! command_exists curl || ! command_exists gpg; then
        record_failure "${nome} (requer curl e gpg)"
        return 0
    fi

    chave_temporaria="$(mktemp /tmp/kali-setup-k6-key.XXXXXX)"
    info 'Configurando o repositório oficial do Grafana k6.'
    if curl --fail --silent --show-error --location \
           --output "$chave_temporaria" https://dl.k6.io/key.gpg &&
       gpg --batch --yes --dearmor \
           --output /usr/share/keyrings/k6-archive-keyring.gpg "$chave_temporaria" &&
       install -o root -g root -m 0644 -- \
           "$K6_SOURCE_FILE" /etc/apt/sources.list.d/k6.list &&
       apt-get update &&
       apt-get install -y -- k6; then
        record_installed "${nome} (repositório oficial Grafana)"
    else
        record_failure "${nome} (repositório oficial Grafana)"
    fi
    rm -f -- "$chave_temporaria"
}

install_gatling() {
    local nome="$1"
    local imagem="$2"
    local bin_dir="${REAL_HOME}/.local/bin"

    if command_is_available gatling; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${nome}"
        return 0
    fi
    if ! command_exists docker; then
        record_failure "${nome} (Docker ausente; execute primeiro o módulo 13)"
        return 0
    fi

    info "Baixando a imagem oficial ${imagem}."
    if docker pull "$imagem" &&
       run_as_real_user "$REAL_USER" mkdir -p -- "$bin_dir" &&
       install -o "$REAL_USER" -g "$(id -gn "$REAL_USER")" -m 0755 -- \
           "$GATLING_LAUNCHER" "${bin_dir}/gatling"; then
        record_installed "${nome} (Docker: ${imagem})"
    else
        record_failure "${nome} (Docker: ${imagem})"
    fi
}

process_inventory() {
    local linha='' nome='' categoria='' prioridade=''
    local metodo='' origem='' validacao='' arquitetura='' comando=''

    while IFS= read -r linha; do
        [[ -z "$linha" || "$linha" == \#* ]] && continue
        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        if [[ -z "$nome" || -z "$categoria" || -z "$prioridade" || -z "$metodo" ||
              -z "$origem" || -z "$validacao" || -z "$arquitetura" ]]; then
            record_failure 'registro inválido em 33-tools-load-testing.txt'
            continue
        fi
        case "$prioridade" in
            CORE|RECOMMENDED|OPTIONAL) ;;
            *)
                warning "Prioridade não instalável para ${nome}: ${prioridade}."
                SKIPPED=$((SKIPPED + 1))
                continue
                ;;
        esac

        comando="${validacao%% *}"
        case "$metodo" in
            apt) install_apt_tool "$nome" "$origem" "$comando" ;;
            pipx) install_pipx_tool "$nome" "$origem" "$comando" ;;
            go) install_go_tool "$nome" "$origem" "$comando" ;;
            k6-repository) install_k6 "$nome" ;;
            docker-image) install_gatling "$nome" "$origem" ;;
            *)
                warning "Método não suportado para ${nome}: ${metodo}."
                SKIPPED=$((SKIPPED + 1))
                ;;
        esac
    done < "$CONFIG_FILE"
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

main() {
    print_banner
    require_root
    require_commands apt-get apt-cache dpkg-query getent sudo install mktemp id
    detect_kali
    validate_regular_file "$CONFIG_FILE"
    validate_regular_file "$K6_SOURCE_FILE"
    validate_regular_file "$GATLING_LAUNCHER"
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    process_inventory

    warning 'Nenhum teste foi iniciado e nenhum limite do sistema foi alterado.'
    warning 'Defina autorização, janela, taxa máxima, duração, monitoramento e critério de interrupção antes de testar.'
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
