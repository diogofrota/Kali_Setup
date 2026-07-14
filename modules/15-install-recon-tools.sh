#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 15
# NOME..........: Instalação de ferramentas de reconhecimento
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Instalar ferramentas de reconhecimento autorizadas usando inventários de Go,
# Python, APT e ferramentas que exigem revisão manual. O módulo cobre
# subdomínios, DNS, HTTP, portas, crawling, URLs, inteligência e organização.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida que o sistema é Kali Linux.
# 3. Lê inventários de ferramentas Go, Python, Git e desabilitadas.
# 4. Instala prioridades CORE e RECOMMENDED.
# 5. Pergunta antes de prioridades OPTIONAL.
# 6. Ignora LEGACY e UNSUPPORTED.
# 7. Não instala ferramentas marcadas como método git sem revisão manual.
#
# RISCOS CONTROLADOS
#
# O módulo instala ferramentas, mas não executa reconhecimento contra alvos. Para
# ferramentas Go, valida o binário esperado em ~/go/bin para evitar conflitos de
# nomes como httpx.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='15-install-recon-tools'
NEXT_MODULE='16-install-web-tools.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"

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
REAL_HOME=''

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 15' \
        '            Ferramentas de Reconhecimento' \
        '============================================================'
}

should_install_priority() {
    local prioridade="$1"
    local nome="$2"

    case "$prioridade" in
        CORE|RECOMMENDED)
            return 0
            ;;
        OPTIONAL)
            confirm_action "Instalar ferramenta opcional de reconhecimento ${nome}?"
            ;;
        LEGACY|UNSUPPORTED)
            warning "Ferramenta ${nome} marcada como ${prioridade}; não será instalada."
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

install_apt_tool() {
    local pacote="$1"

    if apt_package_installed "$pacote"; then
        EXISTING=$((EXISTING + 1))
    else
        if apt_package_exists "$pacote"; then
            apt-get install -y -- "$pacote"
            INSTALLED=$((INSTALLED + 1))
        else
            warning "Pacote ausente: ${pacote}"
            SKIPPED=$((SKIPPED + 1))
        fi
    fi
}

install_go_tool() {
    local origem="$1"
    local validacao="$2"
    local comando="${validacao%% *}"
    local caminho_binario="${REAL_HOME}/go/bin/${comando}"

    if [[ -x "$caminho_binario" ]]; then
        EXISTING=$((EXISTING + 1))
    else
        if command_exists go; then
            run_as_real_user "$REAL_USER" env GOPATH="${REAL_HOME}/go" GOBIN="${REAL_HOME}/go/bin" go install "$origem"
            INSTALLED=$((INSTALLED + 1))
        else
            warning "Go ausente; ferramenta ignorada: ${origem}"
            SKIPPED=$((SKIPPED + 1))
        fi
    fi
}

install_pipx_tool() {
    local origem="$1"
    local validacao="$2"
    local comando="${validacao%% *}"

    if command_exists "$comando"; then
        EXISTING=$((EXISTING + 1))
    else
        if command_exists pipx; then
            run_as_real_user "$REAL_USER" pipx install "$origem"
            INSTALLED=$((INSTALLED + 1))
        else
            warning "pipx ausente; ferramenta ignorada: ${origem}"
            SKIPPED=$((SKIPPED + 1))
        fi
    fi
}

process_file() {
    local arquivo="$1"
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

        if should_install_priority "$prioridade" "$nome"; then
            case "$metodo" in
                apt)
                    install_apt_tool "$origem"
                    ;;
                go)
                    install_go_tool "$origem" "$validacao"
                    ;;
                pipx)
                    install_pipx_tool "$origem" "$validacao"
                    ;;
                git)
                    warning "Método git exige revisão manual: ${nome}"
                    SKIPPED=$((SKIPPED + 1))
                    ;;
                disabled)
                    SKIPPED=$((SKIPPED + 1))
                    ;;
                *)
                    warning "Método desconhecido: ${metodo}"
                    FAILED=$((FAILED + 1))
                    ;;
            esac
        else
            SKIPPED=$((SKIPPED + 1))
        fi
    done 9< "$arquivo"
}

main() {
    print_banner
    require_root
    require_commands apt-get apt-cache dpkg-query getent sudo
    detect_kali
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    info "Categorias: Subdomínios, DNS, HTTP, Portas, Crawling, URLs, Screenshots, Inteligência e Organização."
    process_file "${PROJECT_ROOT}/config/tools-go.txt"
    process_file "${PROJECT_ROOT}/config/tools-python.txt"
    process_file "${PROJECT_ROOT}/config/tools-git.txt"
    process_file "${PROJECT_ROOT}/config/tools-disabled.txt"

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
