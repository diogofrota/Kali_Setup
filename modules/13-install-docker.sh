#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 13
# NOME..........: Instalação do Docker
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Instalar Docker no Kali Linux usando o pacote correto docker.io, configurar
# Docker Compose quando disponível e permitir que o operador decida sobre
# serviço no boot, início imediato e inclusão do usuário no grupo docker.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida que o sistema é Kali Linux.
# 3. Instala docker.io quando ausente.
# 4. Instala docker-compose-plugin ou docker-compose como fallback.
# 5. Pergunta antes de habilitar Docker no boot.
# 6. Pergunta antes de iniciar Docker imediatamente.
# 7. Alerta e pergunta antes de adicionar usuário ao grupo docker.
#
# RISCOS CONTROLADOS
#
# O grupo docker oferece privilégios equivalentes a root. Por isso essa etapa
# nunca é feita sem confirmação. O módulo também evita instalar o pacote errado
# chamado docker.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='13-install-docker'
NEXT_MODULE='14-install-network-tools.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"

# shellcheck source=../lib/common.sh
source "${PROJECT_ROOT}/lib/common.sh"

trap 'kali_setup_handle_error; exit $?' ERR

INSTALLED=0
EXISTING=0
UPDATED=0
SKIPPED=0
FAILED=0
LOG_FILE=''
REAL_USER=''

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 13' \
        '                    Docker' \
        '============================================================'
}

install_docker_package() {
    if apt_package_installed docker.io; then
        EXISTING=$((EXISTING + 1))
    else
        if apt_package_exists docker.io; then
            apt install docker.io
            INSTALLED=$((INSTALLED + 1))
        else
            die "docker.io não encontrado. Não instale o pacote docker por engano."
        fi
    fi
}

install_compose() {
    if apt_package_exists docker-compose-plugin; then
        if apt_package_installed docker-compose-plugin; then
            EXISTING=$((EXISTING + 1))
        else
            apt install docker-compose-plugin
            INSTALLED=$((INSTALLED + 1))
        fi
        return 0
    fi

    if apt_package_exists docker-compose; then
        if apt_package_installed docker-compose; then
            EXISTING=$((EXISTING + 1))
        else
            apt install docker-compose
            INSTALLED=$((INSTALLED + 1))
        fi
    else
        warning "Nenhum pacote compose encontrado."
        SKIPPED=$((SKIPPED + 1))
    fi
}

main() {
    print_banner
    require_root
    require_commands apt apt-cache dpkg-query systemctl usermod getent
    detect_kali
    REAL_USER="$(get_real_user)"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    warning "No Kali, o mecanismo Docker deve ser instalado como docker.io, não como docker."
    install_docker_package
    install_compose

    if confirm_action 'Habilitar o serviço docker no boot?'; then
        systemctl enable docker
        UPDATED=$((UPDATED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi

    if confirm_action 'Iniciar o serviço docker agora?'; then
        systemctl start docker
        UPDATED=$((UPDATED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi

    warning "O grupo docker concede privilégios equivalentes a root."
    if confirm_action "Adicionar ${REAL_USER} ao grupo docker?"; then
        usermod -aG docker "$REAL_USER"
        UPDATED=$((UPDATED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi

    if command_exists docker; then
        if docker version; then
            success "Docker respondeu ao comando de versão."
        else
            warning "Docker instalado, mas o daemon pode não estar em execução."
            SKIPPED=$((SKIPPED + 1))
        fi
    fi

    if docker compose version >/dev/null 2>&1; then
        docker compose version
    else
        if command_exists docker-compose; then
            docker-compose version
        else
            warning "Docker Compose não encontrado ou indisponível."
            SKIPPED=$((SKIPPED + 1))
        fi
    fi

    print_summary_line 'Instaladas' "$INSTALLED"
    print_summary_line 'Já existentes' "$EXISTING"
    print_summary_line 'Atualizadas' "$UPDATED"
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' '0'
    print_summary_line 'Falhas' "$FAILED"
    print_summary_line 'Log' "$LOG_FILE"
    print_summary_line 'Status' "OK ($(detect_architecture))"
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"
}

main "$@"
