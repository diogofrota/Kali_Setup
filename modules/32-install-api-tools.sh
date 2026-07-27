#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 32
# NOME..........: Instalação de ferramentas para pentest de APIs
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Preparar uma workstation profissional para avaliações autorizadas de APIs
# REST, OpenAPI, GraphQL e gRPC. O módulo instala somente ferramentas locais;
# não consulta alvos, baixa wordlists operacionais nem inicia proxies ou scans.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='32-install-api-tools'
NEXT_MODULE='33-install-load-testing-tools.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/32-tools-api.txt"
JWT_TOOL_LAUNCHER="${PROJECT_ROOT}/assets/jwt_tool"

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
        '            KALI SETUP - MÓDULO 32' \
        '              Pentest profissional de APIs' \
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

install_pipx_tool() {
    local nome="$1"
    local origem="$2"
    local comando="$3"

    if command_is_available "$comando"; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${nome}"
    elif ! command_exists pipx; then
        record_failure "${nome} (pipx ausente; execute primeiro o módulo 10)"
    else
        info "Instalando ${nome} via pipx no ambiente do usuário ${REAL_USER}."
        if run_as_real_user "$REAL_USER" env HOME="$REAL_HOME" pipx install "$origem"; then
            record_installed "${nome} (pipx)"
        else
            record_failure "${nome} (pipx: ${origem})"
        fi
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
    else
        info "Compilando ${nome} no ambiente do usuário ${REAL_USER}."
        if run_as_real_user "$REAL_USER" env HOME="$REAL_HOME" \
            GOPATH="${REAL_HOME}/go" GOBIN="${REAL_HOME}/go/bin" go install "$origem"; then
            record_installed "${nome} (Go)"
        else
            record_failure "${nome} (Go: ${origem})"
        fi
    fi
}

install_kiterunner() {
    local nome="$1"
    local origem="$2"
    local diretorio_temporario=''

    if command_is_available kr; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${nome}"
        return 0
    fi
    if ! command_exists git || ! command_exists make || ! command_exists go ||
       ! command_exists g++; then
        record_failure "${nome} (requer git, make, g++ e Go; execute os módulos 06 e 11)"
        return 0
    fi

    diretorio_temporario="$(mktemp -d /tmp/kali-setup-kiterunner.XXXXXX)"
    chown "${REAL_USER}:$(id -gn "$REAL_USER")" "$diretorio_temporario"
    info "Compilando Kiterunner a partir do repositório oficial."
    if run_as_real_user "$REAL_USER" git clone --depth 1 -- "$origem" "${diretorio_temporario}/src" &&
       run_as_real_user "$REAL_USER" env HOME="$REAL_HOME" \
           make -C "${diretorio_temporario}/src" build &&
       install -o root -g root -m 0755 -- "${diretorio_temporario}/src/dist/kr" /usr/local/bin/kr; then
        record_installed "${nome} (/usr/local/bin/kr)"
    else
        record_failure "${nome} (build oficial)"
    fi
    rm -rf -- "$diretorio_temporario"
}

install_jwt_tool() {
    local nome="$1"
    local origem="$2"
    local destino="${REAL_HOME}/.local/share/kali-setup/tools/jwt_tool"
    local bin_dir="${REAL_HOME}/.local/bin"

    if command_is_available jwt_tool; then
        EXISTING=$((EXISTING + 1))
        success "Já instalado: ${nome}"
        return 0
    fi
    if ! command_exists git || ! command_exists python3; then
        record_failure "${nome} (requer git e Python 3)"
        return 0
    fi
    if [[ -e "$destino" ]]; then
        if [[ -f "${destino}/jwt_tool.py" && -x "${destino}/.venv/bin/python" ]]; then
            if run_as_real_user "$REAL_USER" mkdir -p -- "$bin_dir" &&
               install -o "$REAL_USER" -g "$(id -gn "$REAL_USER")" -m 0755 -- \
                   "$JWT_TOOL_LAUNCHER" "${bin_dir}/jwt_tool"; then
                record_installed "${nome} (launcher restaurado em ${bin_dir}/jwt_tool)"
            else
                record_failure "${nome} (não foi possível restaurar o launcher)"
            fi
        else
            record_failure "${nome} (diretório incompleto existente: ${destino})"
        fi
        return 0
    fi

    info "Instalando ${nome} em ambiente virtual isolado."
    if run_as_real_user "$REAL_USER" mkdir -p -- "$(dirname -- "$destino")" "$bin_dir" &&
       run_as_real_user "$REAL_USER" git clone --depth 1 -- "$origem" "$destino" &&
       run_as_real_user "$REAL_USER" python3 -m venv "${destino}/.venv" &&
       run_as_real_user "$REAL_USER" "${destino}/.venv/bin/python" -m pip \
           install --requirement "${destino}/requirements.txt" &&
       install -o "$REAL_USER" -g "$(id -gn "$REAL_USER")" -m 0755 -- \
           "$JWT_TOOL_LAUNCHER" "${bin_dir}/jwt_tool"; then
        record_installed "${nome} (${bin_dir}/jwt_tool)"
    else
        record_failure "${nome} (instalação isolada)"
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
            record_failure 'registro inválido em 32-tools-api.txt'
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
            pipx) install_pipx_tool "$nome" "$origem" "$comando" ;;
            go) install_go_tool "$nome" "$origem" "$comando" ;;
            kiterunner) install_kiterunner "$nome" "$origem" ;;
            jwt-tool) install_jwt_tool "$nome" "$origem" ;;
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
    require_commands getent sudo install mktemp chown id
    detect_kali
    validate_regular_file "$CONFIG_FILE"
    validate_regular_file "$JWT_TOOL_LAUNCHER"
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    process_inventory

    warning 'Nenhuma ferramenta foi executada contra alvos e nenhum proxy foi iniciado.'
    warning 'Use somente com autorização formal, escopo e limites de requisição definidos.'
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
