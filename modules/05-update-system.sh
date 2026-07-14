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
# 4. Atualiza os índices do APT.
# 5. Simula a atualização e mostra apenas um resumo numérico.
# 6. Pergunta antes de aplicar a atualização completa.
# 7. Executa limpeza leve, dpkg --audit e apt-get check.
#
# RISCOS CONTROLADOS
#
# Atualizações podem alterar kernel, bibliotecas, serviços e ferramentas. Por
# isso o módulo não executa a atualização completa sem confirmação do operador
# e registra as ações em log privado.
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
UPGRADE_ACTIONS=0
REMOVE_ACTIONS=0

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

summarize_upgrade_plan() {
    local simulation=''

    info "Verificando quantos pacotes precisam ser atualizados..."
    simulation="$(apt-get --simulate -o Debug::NoLocking=1 dist-upgrade)"

    UPGRADE_ACTIONS="$(
        awk '/^Inst / { total++ } END { print total + 0 }' <<< "$simulation"
    )"
    REMOVE_ACTIONS="$(
        awk '/^Remv / { total++ } END { print total + 0 }' <<< "$simulation"
    )"

    if [[ "$UPGRADE_ACTIONS" -eq 0 && "$REMOVE_ACTIONS" -eq 0 ]]; then
        success "O Kali já está atualizado."
    else
        info "Pacotes para instalar ou atualizar: ${UPGRADE_ACTIONS}."
        if [[ "$REMOVE_ACTIONS" -gt 0 ]]; then
            warning "A atualização precisa remover ${REMOVE_ACTIONS} pacote(s) para resolver dependências."
        fi
    fi

    log_line "Plano: ${UPGRADE_ACTIONS} instalação(ões)/atualização(ões), ${REMOVE_ACTIONS} remoção(ões)."
}

main() {
    print_banner
    require_root
    require_commands apt-get awk dpkg getent grep date uname
    detect_kali

    REAL_USER="$(get_real_user)"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"
    log_line 'Início do módulo de atualização.'

    info "Atualizando os índices do APT..."
    apt-get update
    UPDATED=$((UPDATED + 1))
    log_line 'apt-get update concluído.'

    summarize_upgrade_plan

    if [[ "$UPGRADE_ACTIONS" -eq 0 && "$REMOVE_ACTIONS" -eq 0 ]]; then
        :
    elif confirm_action 'Aplicar agora a atualização completa do Kali?'; then
        apt-get --assume-yes dist-upgrade
        UPDATED=$((UPDATED + 1))
        log_line 'apt-get dist-upgrade concluído.'
    else
        warning "Atualização completa ignorada por escolha do usuário."
        SKIPPED=$((SKIPPED + 1))
        log_line 'apt-get dist-upgrade ignorado.'
    fi

    apt-get autoclean
    log_line 'apt-get autoclean concluído.'

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
