#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 11
# NOME..........: Instalação de Go e ferramentas Go
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Instalar o runtime Go e ferramentas escritas em Go, priorizando instalação no
# home do usuário real em ~/go/bin para evitar misturar binários de pentest com
# arquivos de sistema.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida que o sistema é Kali Linux.
# 3. Cria ~/go/bin com dono e permissões corretas.
# 4. Instala golang-go via APT quando Go ainda não existe.
# 5. Lê config/tools-go.txt.
# 6. Instala ferramentas CORE e RECOMMENDED com go install.
# 7. Pergunta antes de ferramentas OPTIONAL.
#
# RISCOS CONTROLADOS
#
# Algumas ferramentas têm nomes que podem conflitar com outros comandos, como
# httpx. Por isso a validação de ferramentas Go usa o caminho esperado
# ~/go/bin/<comando>, evitando falsos positivos no PATH.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='11-install-go'
NEXT_MODULE='12-install-rust.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/tools-go.txt"

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
ARCHITECTURE=''

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 11' \
        '                   Go Tools' \
        '============================================================'
}

ensure_go_runtime() {
    if command_exists go; then
        success "Go já está instalado."
        EXISTING=$((EXISTING + 1))
        return 0
    fi

    if apt_package_exists golang-go; then
        apt-get install -y -- golang-go
        INSTALLED=$((INSTALLED + 1))
    else
        die "Pacote golang-go não encontrado no apt."
    fi
}

install_go_tool() {
    local nome="$1"
    local prioridade="$2"
    local origem="$3"
    local validacao="$4"
    local comando="${validacao%% *}"
    local caminho_binario="${REAL_HOME}/go/bin/${comando}"

    if [[ -x "$caminho_binario" ]]; then
        EXISTING=$((EXISTING + 1))
        success "Binário Go já existe: ${caminho_binario}"
        return 0
    fi

    case "$prioridade" in
        CORE|RECOMMENDED)
            info "Instalando ${nome} com go install a partir de ${origem}"
            run_as_real_user "$REAL_USER" env GOPATH="${REAL_HOME}/go" GOBIN="${REAL_HOME}/go/bin" go install "$origem"
            INSTALLED=$((INSTALLED + 1))
            ;;
        OPTIONAL)
            if confirm_action "Instalar ferramenta Go opcional ${nome}?"; then
                run_as_real_user "$REAL_USER" env GOPATH="${REAL_HOME}/go" GOBIN="${REAL_HOME}/go/bin" go install "$origem"
                INSTALLED=$((INSTALLED + 1))
            else
                SKIPPED=$((SKIPPED + 1))
            fi
            ;;
        *)
            SKIPPED=$((SKIPPED + 1))
            ;;
    esac
}

process_go_inventory() {
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

        if [[ "$metodo" == 'go' ]]; then
            install_go_tool "$nome" "$prioridade" "$origem" "$validacao"
        fi
    done 9< "$CONFIG_FILE"
}

main() {
    print_banner
    require_root
    require_commands apt-get apt-cache dpkg-query getent sudo mkdir
    detect_kali
    ARCHITECTURE="$(detect_architecture)"
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    ensure_directory "${REAL_HOME}/go/bin" '700' "$REAL_USER" "$REAL_USER"
    ensure_go_runtime
    process_go_inventory

    print_summary_line 'Instaladas' "$INSTALLED"
    print_summary_line 'Já existentes' "$EXISTING"
    print_summary_line 'Atualizadas' '0'
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' '0'
    print_summary_line 'Falhas' "$FAILED"
    print_summary_line 'Log' "$LOG_FILE"
    print_summary_line 'Status' "OK (${ARCHITECTURE})"
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"
}

main "$@"
