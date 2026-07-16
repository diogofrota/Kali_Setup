#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# SCRIPT........: show-tool-inventory
# NOME..........: Exibição tabular do inventário de ferramentas
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Mostrar em formato alinhado todas as ferramentas cadastradas nos inventários
# config/*.txt, facilitando revisão manual de categoria, prioridade, método,
# origem e compatibilidade.
#
# FLUXO DE EXECUÇÃO
#
# 1. Descobre a raiz do projeto.
# 2. Percorre os inventários conhecidos.
# 3. Ignora comentários e linhas vazias.
# 4. Valida se a linha possui os campos mínimos.
# 5. Imprime tabela local sem instalar ou executar ferramentas.
#
# RISCOS CONTROLADOS
#
# O script é somente informativo. Ele não altera sistema, não baixa arquivos e
# não executa comandos de terceiros.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."; pwd -P)"
CONFIG_DIR="${PROJECT_ROOT}/config"

print_file() {
    local arquivo="$1"
    local linha=''
    local nome=''
    local categoria=''
    local prioridade=''
    local metodo=''
    local origem=''
    local validacao=''
    local arquitetura=''

    while IFS= read -r linha; do
        if [[ -z "$linha" ]]; then
            continue
        fi

        if [[ "$linha" == \#* ]]; then
            continue
        fi

        IFS='|' read -r nome categoria prioridade metodo origem validacao arquitetura <<< "$linha"

        if [[ -z "${arquitetura:-}" ]]; then
            printf '[WARN] Linha inválida ignorada em %s\n' "$arquivo" >&2
            continue
        fi

        printf '%-22s %-16s %-12s %-8s %-32s %s\n' "$nome" "$categoria" "$prioridade" "$metodo" "$origem" "$arquitetura"
    done < "$arquivo"
}

main() {
    local arquivo=''

    printf '%-22s %-16s %-12s %-8s %-32s %s\n' 'NOME' 'CATEGORIA' 'PRIORIDADE' 'MÉTODO' 'PACOTE/ORIGEM' 'ARQUITETURA'
    printf '%s\n' '---------------------------------------------------------------------------------------------------------------'

    for arquivo in "$CONFIG_DIR"/06-packages-base.txt "$CONFIG_DIR"/14-packages-network.txt "$CONFIG_DIR"/16-packages-web.txt "$CONFIG_DIR"/17-packages-vulnerability.txt "$CONFIG_DIR"/11-tools-go.txt "$CONFIG_DIR"/10-tools-python.txt "$CONFIG_DIR"/15-tools-git.txt "$CONFIG_DIR"/tools-optional.txt "$CONFIG_DIR"/15-tools-disabled.txt; do
        if [[ -f "$arquivo" ]]; then
            print_file "$arquivo"
        fi
    done
}

main "$@"
