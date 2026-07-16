#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# SCRIPT........: update-git-tools
# NOME..........: Listagem de ferramentas com método Git
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Listar ferramentas do inventário que exigem revisão manual por usarem método
# git, evitando atualizar repositórios externos automaticamente.
#
# FLUXO DE EXECUÇÃO
#
# 1. Abre config/15-tools-git.txt.
# 2. Ignora comentários e linhas vazias.
# 3. Filtra registros cujo método é git.
# 4. Mostra nome e origem para revisão manual.
#
# RISCOS CONTROLADOS
#
# Atualizar código de terceiros via git sem revisão pode introduzir mudanças
# inesperadas. Este script não executa git clone nem git pull.
###############################################################################

set -Eeuo pipefail
umask 077

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."; pwd -P)"
CONFIG_FILE="${PROJECT_ROOT}/config/15-tools-git.txt"

main() {
    local linha=''
    local nome=''
    local categoria=''
    local prioridade=''
    local metodo=''
    local origem=''
    local validacao=''
    local arquitetura=''

    printf '[INFO] Este script apenas lista ferramentas com método git.\n'
    printf '[INFO] Atualizações Git exigem revisão manual do repositório oficial.\n'
    printf '\n'

    while IFS= read -r linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi

        if [[ "$linha" == \#* ]]; then
            continue
        fi

        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        if [[ "$metodo" == 'git' ]]; then
            printf '%-18s %s\n' "$nome" "$origem"
        fi
    done < "$CONFIG_FILE"
}

main "$@"
