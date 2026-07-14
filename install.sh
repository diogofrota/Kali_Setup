#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# ARQUIVO.......: install.sh
# NOME..........: Orquestrador interativo de módulos
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Servir como ponto de entrada controlado para o projeto KALI SETUP. Este
# arquivo lista módulos, valida caminhos, permite execução por número, oferece
# modo de validação sintática e evita que módulos sensíveis sejam chamados sem
# confirmação explícita do operador.
#
# FLUXO DE EXECUÇÃO
#
# 1. Descobre a raiz real do projeto a partir do caminho do próprio script.
# 2. Define a pasta de módulos esperada.
# 3. Lista módulos ou resolve o número informado pelo usuário.
# 4. Valida se o módulo é arquivo regular, executável e não é link simbólico.
# 5. Solicita confirmação extra para módulos que alteram sistema ou usuários.
# 6. Executa o módulo escolhido ou apenas simula a chamada em modo dry-run.
#
# RISCOS CONTROLADOS
#
# Um orquestrador pode executar arquivos errados se aceitar caminhos sem
# validação. Por isso este script não recebe caminho arbitrário de módulo, não
# segue links simbólicos e só executa arquivos presentes na lista interna
# MODULES. Ele também não executa todos os módulos automaticamente.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

RED=''
GREEN=''
YELLOW=''
BLUE=''
NC=''

if [[ -t 1 ]]; then
    if [[ -z "${NO_COLOR:-}" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m'
    fi
fi

info() {
    printf '%b[INFO]%b %s\n' "$BLUE" "$NC" "$*"
}

success() {
    printf '%b[ OK ]%b %s\n' "$GREEN" "$NC" "$*"
}

warning() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*"
}

error() {
    printf '%b[ERRO]%b %s\n' "$RED" "$NC" "$*" >&2
}

handle_error() {
    local codigo_saida="$?"
    local comando_falhou="${BASH_COMMAND}"
    local linha_aproximada="${BASH_LINENO[0]:-${LINENO}}"

    trap - ERR
    printf '\n' >&2
    error "O instalador encontrou um erro."
    error "Comando executado: ${comando_falhou}"
    error "Linha aproximada: ${linha_aproximada}"
    error "Código de saída: ${codigo_saida}"
    printf '\n' >&2
    exit "$codigo_saida"
}

trap handle_error ERR

readonly MODULES=(
    '01-create-user.sh'
    '02-hostname.sh'
    '03-remove-user.sh'
    '04-configure-api-keys.sh'
    '05-update-system.sh'
    '06-base-packages.sh'
    '07-create-directories.sh'
    '08-configure-shell.sh'
    '09-configure-git.sh'
    '10-install-python.sh'
    '11-install-go.sh'
    '12-install-rust.sh'
    '13-install-docker.sh'
    '14-install-network-tools.sh'
    '15-install-recon-tools.sh'
    '16-install-web-tools.sh'
    '17-install-vulnerability-tools.sh'
    '18-install-password-tools.sh'
    '19-install-active-directory-tools.sh'
    '20-install-osint-tools.sh'
    '21-install-cloud-tools.sh'
    '22-install-mobile-tools.sh'
    '23-install-wireless-tools.sh'
    '24-install-forensics-tools.sh'
    '25-install-reporting-tools.sh'
    '26-install-wordlists.sh'
    '27-install-lab-environments.sh'
    '28-configure-tool-paths.sh'
    '29-validate-installation.sh'
    '30-update-security-tools.sh'
)

PROJECT_ROOT=''
MODULES_DIR=''
DRY_RUN=0

discover_project_root() {
    local script_path="${BASH_SOURCE[0]}"
    local script_dir=''

    script_dir="$(cd -- "$(dirname -- "$script_path")"; pwd -P)"
    PROJECT_ROOT="$script_dir"
    MODULES_DIR="${PROJECT_ROOT}/modules"
}

module_by_number() {
    local numero="$1"
    local modulo=''

    for modulo in "${MODULES[@]}"; do
        case "$modulo" in
            "${numero}"-*)
                printf '%s\n' "$modulo"
                return 0
                ;;
        esac
    done

    return 1
}

list_modules() {
    local modulo=''
    local caminho=''

    for modulo in "${MODULES[@]}"; do
        caminho="${MODULES_DIR}/${modulo}"
        if [[ -f "$caminho" ]]; then
            printf '%s\n' "$modulo"
        else
            printf '%s %s\n' "$modulo" '(planejado/ausente)'
        fi
    done
}

validate_module_file() {
    local modulo="$1"
    local caminho="${MODULES_DIR}/${modulo}"

    if [[ "$caminho" != "${MODULES_DIR}/"* ]]; then
        error "Caminho de módulo recusado: ${caminho}"
        exit 1
    fi

    if [[ -L "$caminho" ]]; then
        error "Módulo recusado por ser link simbólico: ${caminho}"
        exit 1
    fi

    if [[ ! -f "$caminho" ]]; then
        error "Módulo não encontrado: ${caminho}"
        exit 1
    fi

    if [[ ! -x "$caminho" ]]; then
        error "Módulo não está executável: ${caminho}"
        exit 1
    fi
}

confirm_sensitive_module() {
    local modulo="$1"
    local resposta=''

    case "$modulo" in
        03-*|05-*|06-*|10-*|11-*|12-*|13-*|14-*|15-*)
            warning "O módulo ${modulo} pode alterar sistema, pacotes, usuários, serviços ou diretórios."
            printf 'Digite EXECUTAR para chamar este módulo: '
            read -r resposta
            if [[ "$resposta" == 'EXECUTAR' ]]; then
                return 0
            fi
            error "Confirmação inválida. Nenhum módulo foi executado."
            exit 1
            ;;
        *)
            return 0
            ;;
    esac
}

run_module() {
    local modulo="$1"
    local caminho="${MODULES_DIR}/${modulo}"

    validate_module_file "$modulo"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        info "DRY-RUN: chamaria ${caminho}"
        return 0
    fi

    confirm_sensitive_module "$modulo"
    "$caminho"
}

validate_scripts() {
    local arquivo=''

    for arquivo in "${PROJECT_ROOT}/install.sh" "${PROJECT_ROOT}/lib/common.sh" "${MODULES_DIR}"/*.sh "${PROJECT_ROOT}/scripts"/*.sh; do
        if [[ -f "$arquivo" ]]; then
            bash -n "$arquivo"
            success "Sintaxe OK: ${arquivo}"
        fi
    done
}

interactive_menu() {
    local escolha=''
    local modulo=''

    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '                    KALI SETUP' \
        '              Instalador Interativo' \
        '============================================================'

    list_modules
    printf '\nEscolha o número do módulo ou 0 para sair: '
    read -r escolha

    if [[ "$escolha" == '0' ]]; then
        success "Nenhum módulo executado."
        exit 0
    fi

    modulo="$(module_by_number "$escolha")"
    run_module "$modulo"
}

main() {
    local modulo=''

    discover_project_root

    case "${1:-}" in
        '--list')
            list_modules
            ;;
        '--module')
            modulo="$(module_by_number "${2:-}")"
            run_module "$modulo"
            ;;
        '--category')
            case "${2:-}" in
                recon)
                    run_module '15-install-recon-tools.sh'
                    ;;
                *)
                    error "Categoria não reconhecida: ${2:-}"
                    exit 1
                    ;;
            esac
            ;;
        '--validate')
            validate_scripts
            ;;
        '--dry-run')
            DRY_RUN=1
            if [[ "${2:-}" == '--module' ]]; then
                modulo="$(module_by_number "${3:-}")"
                run_module "$modulo"
            else
                list_modules
            fi
            ;;
        '')
            interactive_menu
            ;;
        *)
            error "Uso: ./install.sh --list | --module 05 | --category recon | --validate | --dry-run --module 15"
            exit 1
            ;;
    esac
}

main "$@"
