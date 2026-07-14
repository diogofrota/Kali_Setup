#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 05
# NOME..........: Atualização do sistema
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Atualizar os índices de pacotes do Kali Linux, oferecer upgrade completo com
# confirmação explícita, limpar cache antigo e validar a saúde básica do APT e
# do banco de pacotes dpkg.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida que o sistema é Kali Linux.
# 3. Cria log privado no home do usuário real.
# 4. Verifica resolução DNS e capacidade do APT de preparar URIs.
# 5. Executa apt update.
# 6. Lista pacotes atualizáveis.
# 7. Pergunta antes de executar apt full-upgrade.
# 8. Pergunta antes de executar apt autoremove.
# 9. Executa apt autoclean, dpkg --audit e apt-get check.
#
# RISCOS CONTROLADOS
#
# Atualizações podem alterar kernel, bibliotecas, serviços e ferramentas. Por
# isso o módulo não executa full-upgrade nem autoremove sem confirmação do
# operador e registra as ações em log privado.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='05-update-system'
NEXT_MODULE='06-base-packages.sh'
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

print_banner() {
    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' '            KALI SETUP - MÓDULO 05'
    printf '%s\n' '               Atualização do Sistema'
    printf '%s\n' '============================================================'
    printf '\n'
}

log_line() {
    local mensagem="$1"

    if [[ -n "$LOG_FILE" ]]; then
        printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$(detect_architecture)" "$mensagem" >> "$LOG_FILE"
    fi
}

check_connectivity() {
    info "Verificando conectividade sem depender apenas de ping..."

    if getent hosts kali.org >/dev/null 2>&1; then
        success "Resolução DNS funcional."
        log_line 'DNS para kali.org resolvido.'
    else
        warning "DNS para kali.org falhou; apt ainda pode funcionar por cache ou mirror local."
        SKIPPED=$((SKIPPED + 1))
        log_line 'DNS para kali.org falhou.'
    fi

    if apt-get update --print-uris >/dev/null 2>&1; then
        success "APT consegue preparar lista de URIs."
        log_line 'apt-get update --print-uris executado com sucesso.'
    else
        warning "APT não conseguiu preparar URIs; verifique rede e sources.list."
        log_line 'apt-get update --print-uris falhou.'
    fi
}

show_upgradable_packages() {
    info "Listando pacotes atualizáveis..."
    apt list --upgradable
}

main() {
    print_banner
    require_root
    require_commands apt apt-get dpkg getent grep date uname
    detect_kali

    REAL_USER="$(get_real_user)"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"
    log_line 'Início do módulo de atualização.'

    check_connectivity

    info "Executando apt update..."
    apt update
    UPDATED=$((UPDATED + 1))
    log_line 'apt update concluído.'

    show_upgradable_packages

    if confirm_action 'Executar apt full-upgrade agora?'; then
        apt full-upgrade
        UPDATED=$((UPDATED + 1))
        log_line 'apt full-upgrade concluído.'
    else
        warning "full-upgrade ignorado por escolha do usuário."
        SKIPPED=$((SKIPPED + 1))
        log_line 'full-upgrade ignorado.'
    fi

    if confirm_action 'Executar apt autoremove controlado agora?'; then
        apt autoremove
        UPDATED=$((UPDATED + 1))
        log_line 'apt autoremove concluído.'
    else
        warning "autoremove ignorado por escolha do usuário."
        SKIPPED=$((SKIPPED + 1))
    fi

    apt autoclean
    log_line 'apt autoclean concluído.'

    dpkg --audit
    apt-get check

    if [[ -e '/var/run/reboot-required' ]]; then
        warning "Reinicialização recomendada: /var/run/reboot-required existe."
        log_line 'Reboot requerido detectado.'
    fi

    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' '             MÓDULO 05 CONCLUÍDO'
    printf '%s\n' '============================================================'
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
