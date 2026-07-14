#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# SCRIPT........: update-go-tools
# NOME..........: Atualização de ferramentas Go
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Atualizar ferramentas Go classificadas como CORE ou RECOMMENDED no inventário
# config/tools-go.txt usando go install.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma se o comando go existe.
# 2. Pergunta se o operador deseja atualizar ferramentas Go.
# 3. Lê config/tools-go.txt.
# 4. Processa apenas registros com método go.
# 5. Atualiza somente prioridades CORE e RECOMMENDED.
# 6. Ignora ferramentas OPTIONAL por padrão.
#
# RISCOS CONTROLADOS
#
# Atualizações podem alterar comportamento de ferramentas. Por isso o script
# exige confirmação e não atualiza ferramentas opcionais automaticamente.
###############################################################################

set -Eeuo pipefail
umask 077

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."; pwd -P)"
CONFIG_FILE="${PROJECT_ROOT}/config/tools-go.txt"

confirm() {
    local resposta=''

    printf 'Atualizar ferramentas Go CORE/RECOMMENDED com go install? [s/N]: '
    read -r resposta

    case "$resposta" in
        s|S|sim|SIM)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

main() {
    local linha=''
    local nome=''
    local categoria=''
    local prioridade=''
    local metodo=''
    local origem=''
    local validacao=''
    local arquitetura=''

    if ! command -v go >/dev/null 2>&1; then
        printf '[ERRO] Go não encontrado.\n' >&2
        exit 1
    fi

    if confirm; then
        :
    else
        printf '[INFO] Nenhuma atualização executada.\n'
        exit 0
    fi

    while IFS= read -r linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi

        if [[ "$linha" == \#* ]]; then
            continue
        fi

        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        if [[ "$metodo" != 'go' ]]; then
            continue
        fi

        case "$prioridade" in
            CORE|RECOMMENDED)
                printf '[INFO] Atualizando %s de %s\n' "$nome" "$origem"
                go install "$origem"
                ;;
            *)
                printf '[WARN] Ignorando %s por prioridade %s\n' "$nome" "$prioridade"
                ;;
        esac
    done < "$CONFIG_FILE"
}

main "$@"
