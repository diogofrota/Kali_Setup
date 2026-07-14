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
# 4. Prepara ~/.local/bin e ~/.virtualenvs para o usuário real.
# 5. Executa pipx ensurepath como usuário real.
# 6. Instala automaticamente todas as ferramentas via apt ou pipx.
# 7. Mostra no final o que foi instalado e quais itens falharam.
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
declare -a INSTALLED_ITEMS=()
declare -a FAILED_ITEMS=()
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

record_installed() {
    local item="$1"

    INSTALLED=$((INSTALLED + 1))
    INSTALLED_ITEMS+=("$item")
    success "Instalado: ${item}"
}

record_failure() {
    local item="$1"

    FAILED=$((FAILED + 1))
    FAILED_ITEMS+=("$item")
    error "Falha ao instalar ${item}. O módulo continuará com os próximos itens."
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

prepare_python_workspace() {
    # Garante que ferramentas executadas sem root consigam escrever em ~/.local.
    # Preparar o pai separadamente também repara um diretório criado por sudo.
    ensure_directory "${REAL_HOME}/.local" '700' "$REAL_USER" "$REAL_USER"
    ensure_directory "${REAL_HOME}/.local/bin" '700' "$REAL_USER" "$REAL_USER"
    ensure_directory "${REAL_HOME}/.virtualenvs" '700' "$REAL_USER" "$REAL_USER"
}

install_python_runtime() {
    local pacote=''

    for pacote in python3 python3-venv python3-dev pipx; do
        if apt_package_installed "$pacote"; then
            EXISTING=$((EXISTING + 1))
        else
            if apt_package_exists "$pacote"; then
                if apt-get install -y -- "$pacote"; then
                    record_installed "${pacote} (APT/runtime)"
                else
                    record_failure "${pacote} (APT/runtime)"
                fi
            else
                warning "Pacote não encontrado: ${pacote}"
                record_failure "${pacote} (APT/runtime ausente)"
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
    local comando=''
    local caminho_binario=''

    # Mantém o inventário separado da entrada interativa do terminal.
    while IFS= read -r -u 9 linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi
        if [[ "$linha" == \#* ]]; then
            continue
        fi

        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        case "$prioridade" in
            CORE|RECOMMENDED|OPTIONAL)
                ;;
            *)
                warning "Prioridade desconhecida para ${nome}: ${prioridade}. Item ignorado."
                SKIPPED=$((SKIPPED + 1))
                continue
                ;;
        esac

        case "$metodo" in
            apt)
                if apt_package_installed "$origem"; then
                    EXISTING=$((EXISTING + 1))
                else
                    if apt_package_exists "$origem"; then
                        if apt-get install -y -- "$origem"; then
                            record_installed "${nome} (APT: ${origem})"
                        else
                            record_failure "${nome} (APT: ${origem})"
                        fi
                    else
                        warning "Pacote Python via apt ausente: ${origem}"
                        record_failure "${nome} (pacote APT ausente: ${origem})"
                    fi
                fi
                ;;
            pipx)
                comando="${validacao%% *}"
                caminho_binario="${REAL_HOME}/.local/bin/${comando}"

                if [[ -x "$caminho_binario" ]]; then
                    EXISTING=$((EXISTING + 1))
                    success "Ferramenta pipx já existe: ${caminho_binario}"
                elif command_exists pipx; then
                    info "Instalando ${nome} com pipx a partir de ${origem}"
                    if run_as_real_user "$REAL_USER" env HOME="$REAL_HOME" \
                        pipx install --force "$origem"; then
                        if [[ -x "$caminho_binario" ]]; then
                            record_installed "${nome} (pipx: ${origem})"
                        else
                            record_failure "${nome} (pipx não criou ${caminho_binario})"
                        fi
                    else
                        record_failure "${nome} (pipx: ${origem})"
                    fi
                else
                    warning "pipx ausente; não foi possível instalar ${nome}."
                    record_failure "${nome} (pipx ausente)"
                fi
                ;;
            *)
                warning "Método desconhecido para ${nome}: ${metodo}. Item ignorado."
                SKIPPED=$((SKIPPED + 1))
                ;;
        esac
    done 9< "$CONFIG_FILE"
}

main() {
    print_banner
    require_root
    require_commands apt-get apt-cache dpkg-query getent sudo mkdir chmod chown env
    detect_kali
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    prepare_python_workspace
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    validate_regular_file "$CONFIG_FILE"

    install_python_runtime

    if command_exists pipx; then
        if run_as_real_user "$REAL_USER" env HOME="$REAL_HOME" pipx ensurepath; then
            success "PATH do pipx configurado para ${REAL_USER}."
        else
            record_failure 'pipx ensurepath'
        fi
    else
        warning "pipx não está disponível; as ferramentas pipx serão registradas como falhas."
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
    if [[ "$FAILED" -eq 0 ]]; then
        print_summary_line 'Status' 'OK'
    else
        print_summary_line 'Status' 'PARCIAL'
    fi
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"

    if [[ "${#INSTALLED_ITEMS[@]}" -gt 0 ]]; then
        print_result_list 'Instalado nesta execução:' "${INSTALLED_ITEMS[@]}"
    else
        print_result_list 'Instalado nesta execução:'
    fi
    if [[ "$FAILED" -gt 0 ]]; then
        print_result_list 'Não foi possível instalar:' "${FAILED_ITEMS[@]}"
    fi
}

main "$@"
