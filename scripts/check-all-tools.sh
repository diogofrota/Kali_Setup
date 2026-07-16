#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# SCRIPT........: check-all-tools
# NOME..........: Validação geral do inventário de ferramentas
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Verificar, de forma local e sem executar scans, quais ferramentas listadas nos
# inventários do projeto estão disponíveis no sistema.
#
# FLUXO DE EXECUÇÃO
#
# 1. Descobre a raiz do projeto.
# 2. Percorre os inventários em config/.
# 3. Ignora comentários e linhas vazias.
# 4. Extrai o comando de validação de cada ferramenta.
# 5. Confere ferramentas Go em ~/go/bin para evitar conflitos de nomes.
# 6. Exibe resumo de instaladas, ausentes e inválidas.
#
# RISCOS CONTROLADOS
#
# Este script não executa ferramentas contra alvos. Ele usa apenas presença de
# binários locais e não imprime secrets.
###############################################################################

set -Eeuo pipefail
umask 077

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."; pwd -P)"
CONFIG_DIR="${PROJECT_ROOT}/config"

INSTALLED=0
MISSING=0
INVALID=0

check_file() {
    local arquivo="$1"
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

    while IFS= read -r linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi

        if [[ "$linha" == \#* ]]; then
            continue
        fi

        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        if [[ -z "${arquitetura:-}" ]]; then
            printf '[WARN] Registro inválido em %s\n' "$arquivo"
            INVALID=$((INVALID + 1))
            continue
        fi

        comando="${validacao%% *}"
        caminho_go="${HOME}/go/bin/${comando}"

        if [[ "$metodo" == 'go' ]]; then
            if [[ -x "$caminho_go" ]]; then
                printf '[ OK ] %-22s instalado\n' "$nome"
                INSTALLED=$((INSTALLED + 1))
            else
                if command -v "$comando" >/dev/null 2>&1; then
                    printf '[WARN] %-22s conflito/fora do padrão\n' "$nome"
                    MISSING=$((MISSING + 1))
                else
                    printf '[WARN] %-22s ausente\n' "$nome"
                    MISSING=$((MISSING + 1))
                fi
            fi
        else
            if command -v "$comando" >/dev/null 2>&1; then
                printf '[ OK ] %-22s instalado\n' "$nome"
                INSTALLED=$((INSTALLED + 1))
            else
                printf '[WARN] %-22s ausente\n' "$nome"
                MISSING=$((MISSING + 1))
            fi
        fi
    done < "$arquivo"
}

main() {
    local arquivo=''

    for arquivo in "$CONFIG_DIR"/06-packages-base.txt "$CONFIG_DIR"/14-packages-network.txt "$CONFIG_DIR"/16-packages-web.txt "$CONFIG_DIR"/17-packages-vulnerability.txt "$CONFIG_DIR"/11-tools-go.txt "$CONFIG_DIR"/10-tools-python.txt "$CONFIG_DIR"/15-tools-git.txt "$CONFIG_DIR"/tools-optional.txt; do
        if [[ -f "$arquivo" ]]; then
            check_file "$arquivo"
        fi
    done

    printf '\n'
    printf 'Instaladas..........: %s\n' "$INSTALLED"
    printf 'Ausentes............: %s\n' "$MISSING"
    printf 'Inválidas...........: %s\n' "$INVALID"
}

main "$@"
