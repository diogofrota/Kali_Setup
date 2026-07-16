#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# SCRIPT........: check-tool
# NOME..........: Consulta de ferramenta individual no inventário
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Consultar uma ferramenta específica nos inventários do projeto e informar
# categoria, prioridade, método, origem, arquitetura e status local.
#
# FLUXO DE EXECUÇÃO
#
# 1. Recebe o nome da ferramenta.
# 2. Procura a ferramenta nos arquivos config/*.txt conhecidos.
# 3. Valida se o registro possui os campos esperados.
# 4. Extrai o comando de validação.
# 5. Para ferramentas Go, prioriza o binário esperado em ~/go/bin.
# 6. Informa se está instalada, ausente ou em conflito/fora do padrão.
#
# RISCOS CONTROLADOS
#
# A checagem é somente local. O script não instala pacotes, não chama APIs e não
# executa scanners.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."; pwd -P)"
CONFIG_DIR="${PROJECT_ROOT}/config"

error() {
    printf '[ERRO] %s\n' "$*" >&2
}

find_tool_line() {
    local ferramenta="$1"
    local arquivo=''
    local linha=''
    local nome=''

    for arquivo in "$CONFIG_DIR"/06-packages-base.txt "$CONFIG_DIR"/14-packages-network.txt "$CONFIG_DIR"/16-packages-web.txt "$CONFIG_DIR"/17-packages-vulnerability.txt "$CONFIG_DIR"/11-tools-go.txt "$CONFIG_DIR"/10-tools-python.txt "$CONFIG_DIR"/15-tools-git.txt "$CONFIG_DIR"/tools-optional.txt "$CONFIG_DIR"/15-tools-disabled.txt; do
        if [[ ! -f "$arquivo" ]]; then
            continue
        fi

        while IFS= read -r linha; do
            if [[ -z "$linha" ]]; then
                continue
            fi

            if [[ "$linha" == \#* ]]; then
                continue
            fi

            IFS='|' read -r nome _ <<< "$linha"
            if [[ "$nome" == "$ferramenta" ]]; then
                printf '%s\n' "$linha"
                return 0
            fi
        done < "$arquivo"
    done

    return 1
}

main() {
    local ferramenta="${1:-}"
    local linha=''
    local nome=''
    local categoria=''
    local prioridade=''
    local metodo=''
    local origem=''
    local validacao=''
    local arquitetura=''
    local comando=''
    local caminho_go=''

    if [[ -z "$ferramenta" ]]; then
        error "Uso: check-tool.sh <nome>"
        exit 1
    fi

    if linha="$(find_tool_line "$ferramenta")"; then
        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"
    else
        error "Ferramenta não encontrada no inventário: ${ferramenta}"
        exit 1
    fi

    if [[ -z "${arquitetura:-}" ]]; then
        error "Registro inválido no inventário para: ${ferramenta}"
        exit 1
    fi

    comando="${validacao%% *}"
    caminho_go="${HOME}/go/bin/${comando}"

    printf 'Ferramenta..........: %s\n' "$nome"
    printf 'Categoria...........: %s\n' "$categoria"
    printf 'Prioridade..........: %s\n' "$prioridade"
    printf 'Método..............: %s\n' "$metodo"
    printf 'Origem..............: %s\n' "$origem"
    printf 'Arquitetura.........: %s\n' "$arquitetura"

    if [[ "$metodo" == 'go' ]]; then
        if [[ -x "$caminho_go" ]]; then
            printf 'Status..............: INSTALADA\n'
        else
            if command -v "$comando" >/dev/null 2>&1; then
                printf 'Status..............: CONFLITO OU FORA DO PADRÃO\n'
                printf 'Observação..........: comando existe no PATH, mas não em %s\n' "$caminho_go"
                exit 2
            fi

            printf 'Status..............: AUSENTE\n'
            exit 2
        fi
    else
        if command -v "$comando" >/dev/null 2>&1; then
            printf 'Status..............: INSTALADA\n'
        else
            printf 'Status..............: AUSENTE\n'
            exit 2
        fi
    fi
}

main "$@"
