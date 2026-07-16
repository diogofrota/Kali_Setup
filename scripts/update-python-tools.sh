#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# SCRIPT........: update-python-tools
# NOME..........: Atualização de ferramentas Python via pipx
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Atualizar ferramentas Python gerenciadas por pipx conforme o inventário
# config/10-tools-python.txt.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma se pipx existe no sistema.
# 2. Pergunta se o operador deseja atualizar ferramentas Python.
# 3. Lê config/10-tools-python.txt.
# 4. Processa apenas registros com método pipx.
# 5. Executa pipx upgrade para cada origem encontrada.
#
# RISCOS CONTROLADOS
#
# O script não usa pip global nem sudo pip. Atualizações são feitas pelo pipx,
# mantendo isolamento por ferramenta.
###############################################################################

set -Eeuo pipefail
umask 077

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."; pwd -P)"
CONFIG_FILE="${PROJECT_ROOT}/config/10-tools-python.txt"

main() {
    local linha=''
    local nome=''
    local categoria=''
    local prioridade=''
    local metodo=''
    local origem=''
    local validacao=''
    local arquitetura=''
    local resposta=''

    if ! command -v pipx >/dev/null 2>&1; then
        printf '[ERRO] pipx não encontrado.\n' >&2
        exit 1
    fi

    printf 'Atualizar ferramentas Python gerenciadas por pipx? [s/N]: '
    read -r resposta

    case "$resposta" in
        s|S|sim|SIM)
            ;;
        *)
            printf '[INFO] Nenhuma atualização executada.\n'
            exit 0
            ;;
    esac

    while IFS= read -r linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi

        if [[ "$linha" == \#* ]]; then
            continue
        fi

        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        if [[ "$metodo" == 'pipx' ]]; then
            printf '[INFO] Atualizando %s\n' "$origem"
            pipx upgrade "$origem"
        fi
    done < "$CONFIG_FILE"
}

main "$@"
