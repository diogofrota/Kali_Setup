#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 02
# NOME..........: Configuração do hostname
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux
# VERSÃO........: 2.0
#
# OBJETIVO
#
# Configurar o hostname estático e transiente do Kali Linux, manter o hostname
# ativo coerente e garantir que o nome da máquina seja resolvido localmente por
# meio de uma única entrada 127.0.1.1 no arquivo /etc/hosts.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Valida o hostname desejado, os comandos, os caminhos e as permissões.
# 3. Obtém um bloqueio exclusivo para impedir duas execuções simultâneas.
# 4. Lê o estado atual sem modificar o sistema.
# 5. Encerra sem escrever arquivos quando o estado já está correto.
# 6. Cria backups únicos de /etc/hostname e /etc/hosts.
# 7. Prepara uma nova versão de /etc/hosts em um arquivo temporário.
# 8. Altera somente os componentes que realmente precisam de correção.
# 9. Valida o hostname ativo, estático, transiente e os dois arquivos.
# 10. Restaura automaticamente o estado anterior se uma etapa falhar.
#
# RISCOS CONTROLADOS
#
# - Um /etc/hosts incorreto pode impedir que a máquina resolva o próprio nome.
# - Uma interrupção entre duas escritas pode deixar a configuração divergente.
# - Um link simbólico inesperado pode redirecionar uma escrita privilegiada.
# - Duas execuções simultâneas podem sobrescrever mudanças uma da outra.
#
# Para reduzir esses riscos, o módulo valida todos os caminhos antes do uso,
# trabalha com cópias de segurança verificadas, usa escrita temporária seguida
# de renomeação, mantém um bloqueio exclusivo e executa rollback em erros ou
# sinais de interrupção. SIGKILL e perda abrupta de energia não podem ser
# interceptados por Bash; nesses casos, os backups permanentes continuam em
# /var/backups/kali-setup.
#
# CONFIGURAÇÃO PADRÃO
#
# Hostname novo..: kali
#
# O hostname aparece normalmente no prompt no seguinte formato:
#
# usuário@hostname
#
# Exemplo:
#
# diogo@kali
#
# O QUE ESTE SCRIPT FAZ
#
# - Configura os hostnames estático e transiente com hostnamectl.
# - Confirma o hostname ativo apresentado pelo kernel.
# - Atualiza /etc/hostname por meio do systemd-hostnamed.
# - Normaliza a entrada 127.0.1.1 de /etc/hosts.
# - Preserva aliases encontrados nas entradas 127.0.1.1 existentes.
# - Consolida entradas 127.0.1.1 duplicadas em uma única entrada.
# - Cria backups antes de qualquer alteração nos arquivos importantes.
# - Reverte alterações parciais quando ocorre uma falha interceptável.
#
# O QUE ESTE SCRIPT NÃO FAZ
#
# - Não cria nem remove usuários.
# - Não configura DNS, DHCP, interfaces ou endereços IP.
# - Não modifica o pretty hostname armazenado em /etc/machine-info.
# - Não atualiza o sistema e não instala ferramentas.
#
# EXECUÇÃO
#
# sudo ./modules/02-hostname.sh
###############################################################################


###############################################################################
# CONFIGURAÇÕES DE SEGURANÇA DO BASH
###############################################################################

# -E faz o trap ERR ser herdado por funções e substituições de comandos.
#
# -e encerra o fluxo normal quando um comando não tratado retorna erro.
#
# -u transforma o uso de uma variável não definida em erro, evitando que um
# caminho vazio seja utilizado acidentalmente em uma operação privilegiada.
#
# -o pipefail faria uma sequência com pipe falhar se qualquer etapa falhasse.
# Este módulo evita pipes desnecessários, mas mantém a proteção como padrão do
# projeto e para futuras manutenções.
set -Eeuo pipefail

# Um PATH fixo impede que um executável de diretório controlado pelo usuário
# seja encontrado antes do utilitário legítimo do sistema durante a execução
# com sudo. Os diretórios listados são os locais administrativos tradicionais
# do Kali Linux e do Debian.
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

# A localidade C torna previsíveis as comparações e as saídas dos utilitários.
# Isso evita que traduções ou regras regionais alterem uma validação textual.
LC_ALL='C'
export LC_ALL

# A máscara 077 remove, por padrão, permissões de grupo e de outros usuários
# nos novos arquivos e diretórios. Os backups ficam acessíveis somente ao root.
umask 077


###############################################################################
# CONFIGURAÇÃO DO MÓDULO
###############################################################################

# TARGET_HOSTNAME é um rótulo DNS simples, sem domínio. Alterar esta constante
# é a única personalização necessária para escolher outro nome de máquina.
readonly TARGET_HOSTNAME='kali'

# Estes dois arquivos são administrados pelo módulo. Os caminhos são absolutos
# para que o diretório atual nunca influencie uma escrita privilegiada.
readonly HOSTNAME_FILE='/etc/hostname'
readonly HOSTS_FILE='/etc/hosts'

# BACKUP_ROOT recebe um subdiretório exclusivo para cada execução que realmente
# modifica o sistema. Nenhum backup anterior é sobrescrito.
readonly BACKUP_ROOT='/var/backups/kali-setup'
readonly BACKUP_PARENT='/var/backups'

# O bloqueio fica em uma área volátil própria do projeto. O arquivo permanece
# após a execução, mas o bloqueio do kernel é liberado ao fechar o descritor 9.
readonly LOCK_PARENT='/run/lock'
readonly LOCK_ROOT='/run/lock/kali-setup'
readonly LOCK_FILE='/run/lock/kali-setup/02-hostname.lock'
readonly LOCK_FD='9'

# Nome apenas informativo do módulo esperado na sequência do projeto.
readonly NEXT_MODULE='03-remove-user.sh'


###############################################################################
# ESTADO DA EXECUÇÃO
###############################################################################

# As variáveis abaixo são preenchidas somente depois das validações. Valores
# iniciais explícitos evitam falhas provocadas por set -u dentro dos traps.
CURRENT_ACTIVE_HOSTNAME=''
CURRENT_STATIC_HOSTNAME=''
CURRENT_TRANSIENT_HOSTNAME=''
CURRENT_FILE_HOSTNAME=''
CURRENT_FILE_LINE_COUNT='0'
CURRENT_HOSTS_ENTRY=''
CURRENT_HOSTS_ENTRY_COUNT='0'
CURRENT_HOSTS_TARGET_COUNT='0'

FINAL_ACTIVE_HOSTNAME=''
FINAL_STATIC_HOSTNAME=''
FINAL_TRANSIENT_HOSTNAME=''
FINAL_FILE_HOSTNAME=''
FINAL_FILE_LINE_COUNT='0'
FINAL_HOSTS_ENTRY=''
FINAL_HOSTS_ENTRY_COUNT='0'
FINAL_HOSTS_TARGET_COUNT='0'

BACKUP_DIR=''
HOSTNAME_BACKUP=''
HOSTS_BACKUP=''
TEMP_HOSTS_FILE=''

# Flags numéricas usam 0 para falso e 1 para verdadeiro. Elas permitem que o
# tratador de erros saiba exatamente quais ações precisam ser revertidas.
BACKUPS_READY=0
TRANSACTION_ACTIVE=0
HOSTNAME_CHANGE_REQUIRED=0
HOSTS_CHANGE_REQUIRED=0
HOSTNAME_CHANGE_ATTEMPTED=0
CONFIGURATION_CHANGED=0
ROLLBACK_RESULT='Não necessário'


###############################################################################
# CORES DAS MENSAGENS
###############################################################################

# As cores ANSI são usadas somente em um terminal interativo. Ao redirecionar
# a saída para um arquivo, os textos permanecem limpos e fáceis de processar.
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


###############################################################################
# FUNÇÕES DE MENSAGEM
###############################################################################

# printf recebe o formato como argumento fixo. Diferentemente de echo -e, isso
# impede que barras invertidas presentes em uma mensagem sejam reinterpretadas.
info() {
    printf '%b[INFO]%b %s\n' "$BLUE" "$NC" "$*"
}

success() {
    printf '%b[ OK ]%b %s\n' "$GREEN" "$NC" "$*"
}

warning() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*"
}

# O redirecionamento >&2 envia erros ao fluxo de erro padrão. Assim, mensagens
# normais e diagnósticos podem ser registrados separadamente por automações.
error() {
    printf '%b[ERRO]%b %s\n' "$RED" "$NC" "$*" >&2
}

# Esta função produz deliberadamente um status diferente de zero depois que uma
# validação final já exibiu a causa do problema. Uma função nomeada deixa claro
# que o objetivo é acionar ERR e, quando necessário, o rollback da transação.
trigger_transaction_error() {
    return 1
}


###############################################################################
# LIMPEZA DO ARQUIVO TEMPORÁRIO
###############################################################################

cleanup_temporary_file() {
    # Uma string vazia significa que nenhum arquivo temporário foi criado ou
    # que ele já foi movido com sucesso para o destino definitivo.
    if [[ -z "${TEMP_HOSTS_FILE:-}" ]]; then
        return 0
    fi

    # Antes de remover qualquer objeto, confirmamos que o caminho pertence ao
    # padrão criado por este módulo. Essa defesa evita remover um caminho
    # arbitrário caso uma variável seja alterada indevidamente no futuro.
    if [[ "$TEMP_HOSTS_FILE" != "${HOSTS_FILE}.kali-setup."* ]]; then
        warning "Arquivo temporário fora do padrão; remoção recusada: ${TEMP_HOSTS_FILE}"
        TEMP_HOSTS_FILE=''
        return 0
    fi

    # -e confirma a existência. -f exige arquivo regular. -L identifica link
    # simbólico; links são recusados para que rm nunca siga uma referência
    # inesperada criada durante uma execução privilegiada.
    if [[ -e "$TEMP_HOSTS_FILE" ]]; then
        if [[ ! -f "$TEMP_HOSTS_FILE" ]]; then
            warning "O temporário não é um arquivo regular; remoção recusada."
            TEMP_HOSTS_FILE=''
            return 0
        fi

        if [[ -L "$TEMP_HOSTS_FILE" ]]; then
            warning "O temporário tornou-se um link simbólico; remoção recusada."
            TEMP_HOSTS_FILE=''
            return 0
        fi

        # O marcador -- encerra o processamento de opções de rm. Mesmo que um
        # caminho começasse com hífen, ele seria tratado como operando.
        if rm -- "$TEMP_HOSTS_FILE"; then
            info "Arquivo temporário removido com segurança."
        else
            warning "Não foi possível remover o temporário: ${TEMP_HOSTS_FILE}"
        fi
    fi

    TEMP_HOSTS_FILE=''
    return 0
}


###############################################################################
# ROLLBACK DA TRANSAÇÃO
###############################################################################

rollback_configuration() {
    local ROLLBACK_FAILED=0
    local RESTORED_ACTIVE=''
    local RESTORED_STATIC=''
    local RESTORED_TRANSIENT=''

    warning "Iniciando restauração automática da configuração anterior..."

    # O rollback somente é permitido quando as duas cópias foram criadas e
    # comparadas com os arquivos originais. Restaurar um backup incompleto
    # seria mais perigoso do que preservar o estado para análise manual.
    if [[ "$BACKUPS_READY" -ne 1 ]]; then
        error "Rollback recusado: os backups não foram validados."
        TRANSACTION_ACTIVE=0
        return 1
    fi

    # Se hostnamectl chegou a ser chamado, restauramos separadamente o nome
    # estático e o transiente. Os escopos explícitos preservam o pretty hostname.
    if [[ "$HOSTNAME_CHANGE_ATTEMPTED" -eq 1 ]]; then
        if hostnamectl --static set-hostname "$CURRENT_STATIC_HOSTNAME"; then
            success "Hostname estático anterior restaurado."
        else
            error "Falha ao restaurar o hostname estático anterior."
            ROLLBACK_FAILED=1
        fi

        if hostnamectl --transient set-hostname "$CURRENT_TRANSIENT_HOSTNAME"; then
            success "Hostname transiente anterior restaurado."
        else
            error "Falha ao restaurar o hostname transiente anterior."
            ROLLBACK_FAILED=1
        fi
    fi

    # cp --archive preserva modo, proprietário, grupo, timestamps, ACLs e
    # atributos estendidos sempre que o sistema de arquivos oferece suporte.
    # --no-target-directory exige que o último operando seja tratado como o
    # arquivo exato, e -- encerra a leitura de opções.
    if cp --archive --no-target-directory -- "$HOSTNAME_BACKUP" "$HOSTNAME_FILE"; then
        success "Arquivo ${HOSTNAME_FILE} restaurado."
    else
        error "Falha ao restaurar ${HOSTNAME_FILE}."
        ROLLBACK_FAILED=1
    fi

    if cp --archive --no-target-directory -- "$HOSTS_BACKUP" "$HOSTS_FILE"; then
        success "Arquivo ${HOSTS_FILE} restaurado."
    else
        error "Falha ao restaurar ${HOSTS_FILE}."
        ROLLBACK_FAILED=1
    fi

    # hostname com um argumento solicita ao kernel a restauração do nome ativo.
    # Essa etapa é necessária para reproduzir inclusive um estado anterior em
    # que o hostname ativo e o hostname estático estavam divergentes.
    if [[ "$HOSTNAME_CHANGE_ATTEMPTED" -eq 1 ]]; then
        if hostname "$CURRENT_ACTIVE_HOSTNAME"; then
            success "Hostname ativo anterior restaurado."
        else
            error "Falha ao restaurar o hostname ativo anterior."
            ROLLBACK_FAILED=1
        fi
    fi

    # cmp --silent compara os bytes sem imprimir diferenças. O marcador --
    # separa as opções dos dois caminhos. Uma diferença indica rollback parcial.
    if cmp --silent -- "$HOSTNAME_BACKUP" "$HOSTNAME_FILE"; then
        success "Restauração de ${HOSTNAME_FILE} verificada."
    else
        error "${HOSTNAME_FILE} não corresponde ao backup após o rollback."
        ROLLBACK_FAILED=1
    fi

    if cmp --silent -- "$HOSTS_BACKUP" "$HOSTS_FILE"; then
        success "Restauração de ${HOSTS_FILE} verificada."
    else
        error "${HOSTS_FILE} não corresponde ao backup após o rollback."
        ROLLBACK_FAILED=1
    fi

    if [[ "$HOSTNAME_CHANGE_ATTEMPTED" -eq 1 ]]; then
        if RESTORED_ACTIVE="$(hostname)"; then
            if [[ "$RESTORED_ACTIVE" != "$CURRENT_ACTIVE_HOSTNAME" ]]; then
                error "O hostname ativo não retornou ao valor anterior."
                ROLLBACK_FAILED=1
            fi
        else
            error "Não foi possível consultar o hostname ativo restaurado."
            ROLLBACK_FAILED=1
        fi

        if RESTORED_STATIC="$(hostnamectl --static)"; then
            if [[ "$RESTORED_STATIC" != "$CURRENT_STATIC_HOSTNAME" ]]; then
                error "O hostname estático não retornou ao valor anterior."
                ROLLBACK_FAILED=1
            fi
        else
            error "Não foi possível consultar o hostname estático restaurado."
            ROLLBACK_FAILED=1
        fi

        if RESTORED_TRANSIENT="$(hostnamectl --transient)"; then
            if [[ "$RESTORED_TRANSIENT" != "$CURRENT_TRANSIENT_HOSTNAME" ]]; then
                error "O hostname transiente não retornou ao valor anterior."
                ROLLBACK_FAILED=1
            fi
        else
            error "Não foi possível consultar o hostname transiente restaurado."
            ROLLBACK_FAILED=1
        fi
    fi

    TRANSACTION_ACTIVE=0

    if [[ "$ROLLBACK_FAILED" -eq 0 ]]; then
        ROLLBACK_RESULT='Concluído com sucesso'
        success "Configuração anterior restaurada integralmente."
        return 0
    fi

    ROLLBACK_RESULT="INCOMPLETO - consulte ${BACKUP_DIR}"
    error "O rollback foi incompleto. Os backups foram preservados em ${BACKUP_DIR}."
    return 1
}


###############################################################################
# TRATAMENTO DE ERROS E SINAIS
###############################################################################

handle_error() {
    # Todas as expansões ficam na primeira instrução para preservar o código,
    # o comando e a linha associados à falha original antes de outro comando.
    local EXIT_CODE="$?" FAILED_COMMAND="${BASH_COMMAND}" FAILED_LINE="${BASH_LINENO[0]:-${LINENO}}"

    # errtrace também herda ERR dentro de $(...). O rollback jamais deve ocorrer
    # em um subshell, pois as flags atualizadas nele não retornariam ao processo
    # principal e a restauração poderia ser tentada duas vezes. Encerrar somente
    # o subshell faz a atribuição externa falhar; o Bash principal então executa
    # este mesmo tratador uma única vez com acesso ao estado real da transação.
    if [[ "${BASH_SUBSHELL}" -gt 0 ]]; then
        trap - ERR
        exit "$EXIT_CODE"
    fi

    # Remover ERR impede recursão se o próprio rollback falhar. Durante a curta
    # restauração, HUP, INT e TERM são ignorados para que um segundo Ctrl+C ou
    # sinal de encerramento não interrompa o sistema em outro estado parcial.
    # set +e permite tentar todas as restaurações e relatar cada resultado.
    trap - ERR
    trap '' HUP INT TERM
    set +e

    if [[ "$EXIT_CODE" -eq 0 ]]; then
        EXIT_CODE=1
    fi

    printf '\n' >&2
    error "O módulo encontrou um erro."
    error "Comando executado: ${FAILED_COMMAND}"
    error "Linha aproximada: ${FAILED_LINE}"
    error "Código de saída: ${EXIT_CODE}"

    if [[ "$TRANSACTION_ACTIVE" -eq 1 ]]; then
        if rollback_configuration; then
            ROLLBACK_RESULT='Concluído com sucesso'
        else
            ROLLBACK_RESULT="INCOMPLETO - consulte ${BACKUP_DIR}"
        fi
    fi

    cleanup_temporary_file
    printf '\n' >&2
    exit "$EXIT_CODE"
}

handle_signal() {
    local SIGNAL_NAME="$1"
    local EXIT_CODE="$2"

    trap - ERR
    trap '' HUP INT TERM
    set +e

    printf '\n' >&2
    error "Execução interrompida pelo sinal ${SIGNAL_NAME}."

    if [[ "$TRANSACTION_ACTIVE" -eq 1 ]]; then
        if rollback_configuration; then
            ROLLBACK_RESULT='Concluído com sucesso'
        else
            ROLLBACK_RESULT="INCOMPLETO - consulte ${BACKUP_DIR}"
        fi
    fi

    cleanup_temporary_file
    printf '\n' >&2
    exit "$EXIT_CODE"
}

# ERR trata falhas de comandos. HUP, INT e TERM cobrem fechamento do terminal,
# Ctrl+C e solicitação normal de encerramento. EXIT sempre limpa o temporário.
trap handle_error ERR
trap 'handle_signal HUP 129' HUP
trap 'handle_signal INT 130' INT
trap 'handle_signal TERM 143' TERM
trap cleanup_temporary_file EXIT


###############################################################################
# BANNER INICIAL
###############################################################################

# Não usamos clear: ele depende de TERM e pode falhar em execução não interativa.
printf '\n'
printf '%s\n' '============================================================'
printf '%s\n' '            KALI SETUP - MÓDULO 02'
printf '%s\n' '           Configuração do Hostname'
printf '%s\n' '============================================================'
printf '\n'


###############################################################################
# VERIFICAR PRIVILÉGIOS ADMINISTRATIVOS
###############################################################################

info 'Verificando privilégios administrativos...'

# EUID é uma variável interna do Bash com o identificador efetivo do usuário.
# O root possui EUID 0. A alteração do hostname, de /etc e de /var/backups exige
# esse privilégio; continuar como usuário comum produziria um estado parcial.
if [[ "$EUID" -ne 0 ]]; then
    error 'Este módulo precisa ser executado com privilégios administrativos.'
    printf '\n' >&2
    printf '%s\n' 'Execute:' >&2
    printf '\n' >&2
    printf '%s\n' '    sudo ./modules/02-hostname.sh' >&2
    printf '\n' >&2
    exit 1
fi

success 'Privilégios administrativos confirmados.'


###############################################################################
# VALIDAR O HOSTNAME DE DESTINO
###############################################################################

info "Validando o hostname de destino '${TARGET_HOSTNAME}'..."

# Este projeto utiliza um único rótulo DNS. Por isso, o limite adotado é de 63
# caracteres, não o limite maior aplicável a um FQDN composto por vários rótulos.
if [[ -z "$TARGET_HOSTNAME" ]]; then
    error 'O hostname de destino não pode ser vazio.'
    exit 1
fi

if [[ "${#TARGET_HOSTNAME}" -gt 63 ]]; then
    error 'O hostname de destino possui mais de 63 caracteres.'
    exit 1
fi

# A expressão exige início e fim alfanuméricos. Entre eles, permite somente
# letras ASCII minúsculas, números e hífen. Pontos e espaços são recusados para
# manter o hostname como um único rótulo e evitar ambiguidades com um FQDN.
if [[ ! "$TARGET_HOSTNAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    error "O hostname '${TARGET_HOSTNAME}' possui um formato inválido."
    exit 1
fi

# localhost é reservado para a própria pilha de loopback e não deve identificar
# uma estação real na rede. A validação evita uma configuração semanticamente
# incorreta mesmo que o texto respeite a expressão regular.
if [[ "$TARGET_HOSTNAME" == 'localhost' ]]; then
    error "O hostname reservado 'localhost' não pode ser utilizado."
    exit 1
fi

success 'Hostname de destino validado.'


###############################################################################
# VERIFICAR OS COMANDOS NECESSÁRIOS
###############################################################################

info 'Verificando os comandos necessários...'

# Cada item abaixo é chamado posteriormente pelo módulo:
#
# awk.........: lê, transforma e valida campos dos arquivos de texto.
# cmp.........: confirma que os backups são cópias byte a byte.
# chmod.......: restringe diretórios antigos do projeto ao usuário root.
# cp..........: cria backups preservando atributos.
# date........: compõe um nome legível para o diretório de backup.
# flock.......: impede execuções concorrentes.
# hostname....: consulta e, no rollback, restaura o hostname ativo.
# hostnamectl.: consulta e altera os hostnames gerenciados pelo systemd.
# mkdir.......: cria diretórios privados de lock e backup.
# mktemp......: cria nomes temporários imprevisíveis sem colisão.
# mv..........: instala atomicamente a nova versão de /etc/hosts.
# rm..........: remove somente o arquivo temporário validado.
# stat........: verifica proprietário e permissões dos caminhos.
REQUIRED_COMMANDS=(
    awk
    chmod
    cmp
    cp
    date
    flock
    hostname
    hostnamectl
    mkdir
    mktemp
    mv
    rm
    stat
)

for REQUIRED_COMMAND in "${REQUIRED_COMMANDS[@]}"; do
    # command -v consulta como o Bash resolveria o nome. A saída é descartada;
    # somente o código de retorno interessa para esta validação.
    if command -v "$REQUIRED_COMMAND" >/dev/null 2>&1; then
        info "Comando encontrado: ${REQUIRED_COMMAND}"
    else
        error "O comando obrigatório '${REQUIRED_COMMAND}' não foi encontrado no PATH seguro."
        exit 1
    fi
done

success 'Todos os comandos obrigatórios foram encontrados.'


###############################################################################
# VALIDAR CAMINHOS ABSOLUTOS
###############################################################################

validate_absolute_path() {
    local PATH_TO_VALIDATE="$1"
    local PATH_DESCRIPTION="$2"

    # O padrão /* garante que o caminho comece na raiz. Caminhos relativos são
    # recusados porque seu destino mudaria conforme o diretório de execução.
    if [[ "$PATH_TO_VALIDATE" != /* ]]; then
        error "${PATH_DESCRIPTION} não utiliza um caminho absoluto: ${PATH_TO_VALIDATE}"
        return 1
    fi

    # Caracteres de controle dificultam logs e podem separar argumentos de
    # maneira inesperada. Nenhum caminho legítimo deste módulo precisa deles.
    if [[ "$PATH_TO_VALIDATE" == *$'\n'* ]]; then
        error "${PATH_DESCRIPTION} contém uma quebra de linha inválida."
        return 1
    fi

    if [[ "$PATH_TO_VALIDATE" == *$'\r'* ]]; then
        error "${PATH_DESCRIPTION} contém um retorno de carro inválido."
        return 1
    fi

    if [[ "$PATH_TO_VALIDATE" == *$'\t'* ]]; then
        error "${PATH_DESCRIPTION} contém uma tabulação inválida."
        return 1
    fi

    # Componentes /../ e /./ tornam a interpretação menos evidente durante uma
    # auditoria. Os caminhos canônicos definidos pelo projeto não os utilizam.
    if [[ "$PATH_TO_VALIDATE" == *'/../'* ]]; then
        error "${PATH_DESCRIPTION} contém o componente inseguro /../."
        return 1
    fi

    if [[ "$PATH_TO_VALIDATE" == */.. ]]; then
        error "${PATH_DESCRIPTION} termina com o componente inseguro /..."
        return 1
    fi

    if [[ "$PATH_TO_VALIDATE" == *'/./'* ]]; then
        error "${PATH_DESCRIPTION} contém o componente redundante /./."
        return 1
    fi

    return 0
}

# As funções retornam status diferente de zero em falhas. Como são chamadas no
# fluxo principal, set -e e o trap ERR interrompem o módulo de forma controlada.
validate_absolute_path "$HOSTNAME_FILE" 'Arquivo de hostname'
validate_absolute_path "$HOSTS_FILE" 'Arquivo hosts'
validate_absolute_path "$BACKUP_PARENT" 'Diretório-pai dos backups'
validate_absolute_path "$BACKUP_ROOT" 'Diretório de backups'
validate_absolute_path "$LOCK_PARENT" 'Diretório-pai do bloqueio'
validate_absolute_path "$LOCK_ROOT" 'Diretório privado do bloqueio'
validate_absolute_path "$LOCK_FILE" 'Arquivo de bloqueio'

success 'Caminhos absolutos validados.'


###############################################################################
# VALIDAR ARQUIVOS IMPORTANTES
###############################################################################

validate_important_file() {
    local FILE_PATH="$1"
    local FILE_DESCRIPTION="$2"
    local FILE_OWNER_UID=''
    local FILE_MODE=''
    local FILE_MODE_OCTAL=0

    # -e confirma a existência, -f exige arquivo regular e -L identifica link
    # simbólico. Embora -f siga links, o teste -L separado permite recusá-los.
    if [[ ! -e "$FILE_PATH" ]]; then
        error "${FILE_DESCRIPTION} não existe: ${FILE_PATH}"
        return 1
    fi

    if [[ -L "$FILE_PATH" ]]; then
        error "${FILE_DESCRIPTION} é um link simbólico; alteração recusada: ${FILE_PATH}"
        return 1
    fi

    if [[ ! -f "$FILE_PATH" ]]; then
        error "${FILE_DESCRIPTION} não é um arquivo regular: ${FILE_PATH}"
        return 1
    fi

    # -r e -w validam leitura e escrita para o usuário efetivo root. Uma mídia
    # somente leitura ainda pode falhar no momento da escrita; nesse caso, o trap
    # interromperá a transação sem esconder o erro do sistema operacional.
    if [[ ! -r "$FILE_PATH" ]]; then
        error "${FILE_DESCRIPTION} não possui permissão de leitura: ${FILE_PATH}"
        return 1
    fi

    if [[ ! -w "$FILE_PATH" ]]; then
        error "${FILE_DESCRIPTION} não possui permissão de escrita: ${FILE_PATH}"
        return 1
    fi

    # stat --format=%u devolve o UID numérico do proprietário. Exigimos UID 0
    # porque arquivos críticos pertencentes a outro usuário indicam uma condição
    # anormal que deve ser investigada antes de continuar.
    FILE_OWNER_UID="$(stat --format='%u' -- "$FILE_PATH")"

    if [[ "$FILE_OWNER_UID" != '0' ]]; then
        error "${FILE_DESCRIPTION} não pertence ao root: ${FILE_PATH}"
        return 1
    fi

    # %a fornece o modo em notação octal, como 644. O padrão aceita três ou
    # quatro dígitos. A conversão 8# informa explicitamente a base octal ao Bash.
    FILE_MODE="$(stat --format='%a' -- "$FILE_PATH")"

    if [[ ! "$FILE_MODE" =~ ^[0-7]{3,4}$ ]]; then
        error "Não foi possível interpretar as permissões de ${FILE_PATH}: ${FILE_MODE}"
        return 1
    fi

    FILE_MODE_OCTAL=$((8#${FILE_MODE}))

    # A máscara decimal 18 corresponde ao modo octal 0022. Qualquer bit ativo
    # indica escrita para grupo ou outros, condição insegura em arquivos de /etc.
    if (( (FILE_MODE_OCTAL & 18) != 0 )); then
        error "${FILE_DESCRIPTION} permite escrita por grupo ou outros: modo ${FILE_MODE}"
        return 1
    fi

    return 0
}

info 'Validando arquivos de configuração e suas permissões...'

validate_important_file "$HOSTNAME_FILE" 'Arquivo de hostname'
validate_important_file "$HOSTS_FILE" 'Arquivo hosts'

success 'Arquivos importantes validados.'


###############################################################################
# VALIDAR O AMBIENTE SYSTEMD
###############################################################################

info 'Verificando se o systemd está disponível...'

# /run/systemd/system é criado pelo systemd durante a inicialização. Sua ausência
# geralmente indica chroot, contêiner sem systemd ou outro sistema de init, onde
# hostnamectl não conseguiria concluir a operação pela interface D-Bus.
if [[ ! -d '/run/systemd/system' ]]; then
    error 'O systemd não parece ser o sistema de inicialização ativo.'
    error 'Execute este módulo em uma instalação Kali inicializada com systemd.'
    exit 1
fi

success 'Ambiente systemd confirmado.'


###############################################################################
# VALIDAR DIRETÓRIOS CONTROLADOS PELO ROOT
###############################################################################

validate_root_directory() {
    local DIRECTORY_PATH="$1"
    local DIRECTORY_DESCRIPTION="$2"
    local DIRECTORY_OWNER_UID=''

    if [[ ! -e "$DIRECTORY_PATH" ]]; then
        error "${DIRECTORY_DESCRIPTION} não existe: ${DIRECTORY_PATH}"
        return 1
    fi

    if [[ -L "$DIRECTORY_PATH" ]]; then
        error "${DIRECTORY_DESCRIPTION} é um link simbólico: ${DIRECTORY_PATH}"
        return 1
    fi

    if [[ ! -d "$DIRECTORY_PATH" ]]; then
        error "${DIRECTORY_DESCRIPTION} não é um diretório: ${DIRECTORY_PATH}"
        return 1
    fi

    if [[ ! -w "$DIRECTORY_PATH" ]]; then
        error "${DIRECTORY_DESCRIPTION} não permite escrita: ${DIRECTORY_PATH}"
        return 1
    fi

    DIRECTORY_OWNER_UID="$(stat --format='%u' -- "$DIRECTORY_PATH")"

    if [[ "$DIRECTORY_OWNER_UID" != '0' ]]; then
        error "${DIRECTORY_DESCRIPTION} não pertence ao root: ${DIRECTORY_PATH}"
        return 1
    fi

    return 0
}

validate_private_directory() {
    local DIRECTORY_PATH="$1"
    local DIRECTORY_DESCRIPTION="$2"
    local DIRECTORY_MODE=''
    local DIRECTORY_MODE_OCTAL=0

    validate_root_directory "$DIRECTORY_PATH" "$DIRECTORY_DESCRIPTION"

    DIRECTORY_MODE="$(stat --format='%a' -- "$DIRECTORY_PATH")"

    if [[ ! "$DIRECTORY_MODE" =~ ^[0-7]{3,4}$ ]]; then
        error "Não foi possível interpretar as permissões de ${DIRECTORY_PATH}."
        return 1
    fi

    DIRECTORY_MODE_OCTAL=$((8#${DIRECTORY_MODE}))

    # A máscara decimal 63 corresponde ao modo octal 0077. Nenhum desses bits
    # pode estar ativo em um diretório que contém locks ou backups do root.
    if (( (DIRECTORY_MODE_OCTAL & 63) != 0 )); then
        error "${DIRECTORY_DESCRIPTION} deve ser privado do root: modo ${DIRECTORY_MODE}"
        return 1
    fi

    return 0
}

secure_private_directory() {
    local DIRECTORY_PATH="$1"
    local DIRECTORY_DESCRIPTION="$2"
    local DIRECTORY_MODE=''
    local DIRECTORY_MODE_OCTAL=0

    # Primeiro validamos existência, tipo, proprietário e escrita. Somente após
    # essas confirmações o módulo pode alterar permissões de um diretório antigo.
    validate_root_directory "$DIRECTORY_PATH" "$DIRECTORY_DESCRIPTION"

    DIRECTORY_MODE="$(stat --format='%a' -- "$DIRECTORY_PATH")"

    if [[ ! "$DIRECTORY_MODE" =~ ^[0-7]{3,4}$ ]]; then
        error "Não foi possível interpretar as permissões de ${DIRECTORY_PATH}."
        return 1
    fi

    DIRECTORY_MODE_OCTAL=$((8#${DIRECTORY_MODE}))

    # A versão anterior criava BACKUP_ROOT conforme a umask do ambiente e podia
    # deixá-lo como 0755. Como o caminho pertence ao projeto e já foi validado,
    # corrigimos esse legado para 0700 em vez de bloquear futuras execuções.
    if (( (DIRECTORY_MODE_OCTAL & 63) != 0 )); then
        warning "Restringindo ${DIRECTORY_PATH} ao usuário root."

        # chmod --mode=0700 concede leitura, escrita e travessia somente ao dono.
        # O marcador -- encerra as opções antes do caminho validado.
        chmod --mode=0700 -- "$DIRECTORY_PATH"
    fi

    # Uma nova leitura confirma que a permissão solicitada foi realmente aplicada.
    validate_private_directory "$DIRECTORY_PATH" "$DIRECTORY_DESCRIPTION"
    return 0
}


###############################################################################
# OBTER BLOQUEIO EXCLUSIVO
###############################################################################

info 'Obtendo bloqueio exclusivo do módulo...'

validate_root_directory "$LOCK_PARENT" 'Diretório-pai do bloqueio'

if [[ -e "$LOCK_ROOT" ]]; then
    secure_private_directory "$LOCK_ROOT" 'Diretório privado do bloqueio'
else
    # mkdir --mode=0700 cria o diretório acessível apenas pelo root. O marcador
    # -- encerra opções. A ausência de -p é intencional: uma criação concorrente
    # deve falhar claramente, em vez de aceitar um objeto inesperado.
    mkdir --mode=0700 -- "$LOCK_ROOT"
    secure_private_directory "$LOCK_ROOT" 'Diretório privado do bloqueio'
fi

# Se o arquivo persistente já existe, ele precisa ser regular, não simbólico e
# pertencente ao root. O diretório 0700 impede que usuários comuns o substituam.
if [[ -e "$LOCK_FILE" ]]; then
    validate_important_file "$LOCK_FILE" 'Arquivo de bloqueio'
fi

# exec com redirecionamento abre o arquivo no descritor 9 durante toda a vida do
# processo. A máscara 077 protege um arquivo novo. O caminho já foi validado e
# está dentro de um diretório privado pertencente ao root.
exec 9>"$LOCK_FILE"

validate_important_file "$LOCK_FILE" 'Arquivo de bloqueio'

# --exclusive solicita exclusividade. --nonblock retorna imediatamente quando
# outra execução já possui o lock. O parâmetro 9 identifica o descritor aberto.
if flock --exclusive --nonblock "$LOCK_FD"; then
    success 'Bloqueio exclusivo obtido.'
else
    error 'Outra execução do módulo 02 já está em andamento.'
    exit 1
fi


###############################################################################
# LER O ESTADO ATUAL
###############################################################################

info 'Lendo a configuração atual...'

# hostname sem opções consulta o nome ativo mantido pelo kernel.
CURRENT_ACTIVE_HOSTNAME="$(hostname)"

# --static e --transient selecionam individualmente os dois nomes administrados
# pelo systemd-hostnamed. Essa leitura também confirma que hostnamectl e D-Bus
# estão funcionais antes da criação dos backups e do início da transação.
CURRENT_STATIC_HOSTNAME="$(hostnamectl --static)"
CURRENT_TRANSIENT_HOSTNAME="$(hostnamectl --transient)"

if [[ -z "$CURRENT_ACTIVE_HOSTNAME" ]]; then
    error 'O hostname ativo retornou vazio.'
    exit 1
fi

if [[ -z "$CURRENT_STATIC_HOSTNAME" ]]; then
    error 'O hostname estático retornou vazio.'
    exit 1
fi

if [[ -z "$CURRENT_TRANSIENT_HOSTNAME" ]]; then
    error 'O hostname transiente retornou vazio.'
    exit 1
fi

# awk NR==1 imprime somente a primeira linha de /etc/hostname. A regra END
# imprime a quantidade real de linhas. Não removemos espaços: qualquer caractere
# adicional deve causar correção, e não uma falsa validação como hostname válido.
CURRENT_FILE_HOSTNAME="$(awk 'NR == 1 { print; exit }' "$HOSTNAME_FILE")"
CURRENT_FILE_LINE_COUNT="$(awk 'END { print NR }' "$HOSTNAME_FILE")"

# $1 e $2 representam o endereço e o hostname canônico em /etc/hosts. As três
# consultas obtêm a primeira entrada, o total de entradas 127.0.1.1 e quantas
# delas já registram TARGET_HOSTNAME como o segundo campo.
CURRENT_HOSTS_ENTRY="$(awk '$1 == "127.0.1.1" { print; exit }' "$HOSTS_FILE")"
CURRENT_HOSTS_ENTRY_COUNT="$(awk '$1 == "127.0.1.1" { COUNT += 1 } END { print COUNT + 0 }' "$HOSTS_FILE")"
CURRENT_HOSTS_TARGET_COUNT="$(
    awk -v TARGET="$TARGET_HOSTNAME" '
        $1 == "127.0.1.1" {
            if ($2 == TARGET) {
                COUNT += 1
            }
        }

        END {
            print COUNT + 0
        }
    ' "$HOSTS_FILE"
)"

# Os contadores alimentam decisões numéricas. Validar seu formato antes evita
# que uma saída inesperada seja interpretada por uma expressão aritmética.
for NUMERIC_VALUE in \
    "$CURRENT_FILE_LINE_COUNT" \
    "$CURRENT_HOSTS_ENTRY_COUNT" \
    "$CURRENT_HOSTS_TARGET_COUNT"; do
    if [[ ! "$NUMERIC_VALUE" =~ ^[0-9]+$ ]]; then
        error "Um contador de validação retornou um valor inválido: ${NUMERIC_VALUE}"
        exit 1
    fi
done

success 'Configuração atual lida com sucesso.'


###############################################################################
# DETERMINAR SE EXISTEM ALTERAÇÕES REAIS
###############################################################################

# O hostname precisa ser corrigido se qualquer uma das quatro representações
# estiver divergente. Verificar apenas hostname deixaria /etc/hostname incorreto
# quando o valor ativo já estivesse certo.
if [[ "$CURRENT_ACTIVE_HOSTNAME" != "$TARGET_HOSTNAME" ]]; then
    HOSTNAME_CHANGE_REQUIRED=1
fi

if [[ "$CURRENT_STATIC_HOSTNAME" != "$TARGET_HOSTNAME" ]]; then
    HOSTNAME_CHANGE_REQUIRED=1
fi

if [[ "$CURRENT_TRANSIENT_HOSTNAME" != "$TARGET_HOSTNAME" ]]; then
    HOSTNAME_CHANGE_REQUIRED=1
fi

if [[ "$CURRENT_FILE_LINE_COUNT" -ne 1 ]]; then
    HOSTNAME_CHANGE_REQUIRED=1
else
    if [[ "$CURRENT_FILE_HOSTNAME" != "$TARGET_HOSTNAME" ]]; then
        HOSTNAME_CHANGE_REQUIRED=1
    fi
fi

# /etc/hosts está correto somente quando existe exatamente uma entrada
# 127.0.1.1 e seu segundo campo é o hostname desejado. Aliases posteriores são
# permitidos e preservados, pois também podem ser úteis à resolução local.
HOSTS_CHANGE_REQUIRED=1

if [[ "$CURRENT_HOSTS_ENTRY_COUNT" -eq 1 ]]; then
    if [[ "$CURRENT_HOSTS_TARGET_COUNT" -eq 1 ]]; then
        HOSTS_CHANGE_REQUIRED=0
    fi
fi

printf '\n'
printf '%-24s %s\n' 'Hostname ativo atual...:' "$CURRENT_ACTIVE_HOSTNAME"
printf '%-24s %s\n' 'Hostname estático atual.:' "$CURRENT_STATIC_HOSTNAME"
printf '%-24s %s\n' 'Hostname transiente atual:' "$CURRENT_TRANSIENT_HOSTNAME"
printf '%-24s %s\n' 'Hostname desejado.......:' "$TARGET_HOSTNAME"
printf '%-24s %s\n' 'Entrada hosts atual.....:' "${CURRENT_HOSTS_ENTRY:-não encontrada}"
printf '\n'


###############################################################################
# CRIAR DIRETÓRIO E BACKUPS DA TRANSAÇÃO
###############################################################################

create_verified_backups() {
    local TIMESTAMP=''

    info 'Preparando o diretório seguro de backups...'

    validate_root_directory "$BACKUP_PARENT" 'Diretório-pai dos backups'

    if [[ -e "$BACKUP_ROOT" ]]; then
        secure_private_directory "$BACKUP_ROOT" 'Diretório de backups do projeto'
    else
        # --mode=0700 restringe o novo diretório ao root. -- marca o fim das
        # opções. Não usamos -p porque BACKUP_PARENT já foi validado acima.
        mkdir --mode=0700 -- "$BACKUP_ROOT"
        secure_private_directory "$BACKUP_ROOT" 'Diretório de backups do projeto'
    fi

    # date recebe um formato iniciado por +. Ano, mês, dia, hora, minuto e
    # segundo deixam o diretório legível para o administrador.
    TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

    if [[ ! "$TIMESTAMP" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
        error "O timestamp de backup possui formato inesperado: ${TIMESTAMP}"
        return 1
    fi

    # mktemp --directory cria atomicamente um diretório. Os seis X são trocados
    # por caracteres imprevisíveis, impedindo colisões mesmo no mesmo segundo.
    BACKUP_DIR="$(mktemp --directory "${BACKUP_ROOT}/${TIMESTAMP}-XXXXXX")"

    validate_absolute_path "$BACKUP_DIR" 'Diretório da transação de backup'
    validate_private_directory "$BACKUP_DIR" 'Diretório da transação de backup'

    HOSTNAME_BACKUP="${BACKUP_DIR}/hostname.bak"
    HOSTS_BACKUP="${BACKUP_DIR}/hosts.bak"

    validate_absolute_path "$HOSTNAME_BACKUP" 'Backup do arquivo hostname'
    validate_absolute_path "$HOSTS_BACKUP" 'Backup do arquivo hosts'

    # O diretório acabou de ser criado e os destinos não podem existir. Essa
    # confirmação garante que cp nunca sobrescreva um backup anterior.
    if [[ -e "$HOSTNAME_BACKUP" ]]; then
        error "O destino do backup já existe: ${HOSTNAME_BACKUP}"
        return 1
    fi

    if [[ -e "$HOSTS_BACKUP" ]]; then
        error "O destino do backup já existe: ${HOSTS_BACKUP}"
        return 1
    fi

    info "Criando backups em ${BACKUP_DIR}..."

    # --archive preserva conteúdo e atributos. --no-target-directory impede que
    # um destino transformado em diretório mude silenciosamente o caminho final.
    # -- encerra as opções antes dos operandos de origem e destino.
    cp --archive --no-target-directory -- "$HOSTNAME_FILE" "$HOSTNAME_BACKUP"
    cp --archive --no-target-directory -- "$HOSTS_FILE" "$HOSTS_BACKUP"

    validate_important_file "$HOSTNAME_BACKUP" 'Backup do arquivo hostname'
    validate_important_file "$HOSTS_BACKUP" 'Backup do arquivo hosts'

    # A cópia só é considerada válida depois de uma comparação byte a byte.
    if cmp --silent -- "$HOSTNAME_FILE" "$HOSTNAME_BACKUP"; then
        success "Backup verificado: ${HOSTNAME_BACKUP}"
    else
        error "O backup de ${HOSTNAME_FILE} não corresponde ao original."
        return 1
    fi

    if cmp --silent -- "$HOSTS_FILE" "$HOSTS_BACKUP"; then
        success "Backup verificado: ${HOSTS_BACKUP}"
    else
        error "O backup de ${HOSTS_FILE} não corresponde ao original."
        return 1
    fi

    BACKUPS_READY=1
    return 0
}


###############################################################################
# PREPARAR A NOVA VERSÃO DE /etc/hosts
###############################################################################

prepare_hosts_update() {
    local TEMP_ENTRY_COUNT='0'
    local TEMP_TARGET_COUNT='0'

    info "Preparando uma nova versão de ${HOSTS_FILE}..."

    # O modelo fica no mesmo diretório de /etc/hosts. Assim, mv poderá executar
    # uma renomeação no mesmo sistema de arquivos. mktemp cria um arquivo regular
    # exclusivo e substitui XXXXXX por caracteres imprevisíveis.
    TEMP_HOSTS_FILE="$(mktemp "${HOSTS_FILE}.kali-setup.XXXXXX")"

    validate_absolute_path "$TEMP_HOSTS_FILE" 'Arquivo hosts temporário'

    if [[ "$TEMP_HOSTS_FILE" != "${HOSTS_FILE}.kali-setup."* ]]; then
        error "mktemp retornou um caminho fora do padrão esperado: ${TEMP_HOSTS_FILE}"
        return 1
    fi

    if [[ ! -f "$TEMP_HOSTS_FILE" ]]; then
        error "O arquivo temporário não é regular: ${TEMP_HOSTS_FILE}"
        return 1
    fi

    if [[ -L "$TEMP_HOSTS_FILE" ]]; then
        error "O arquivo temporário é um link simbólico: ${TEMP_HOSTS_FILE}"
        return 1
    fi

    # Copiar primeiro o original com --archive transfere proprietário, grupo,
    # modo, ACLs, contexto de segurança e atributos estendidos para o temporário.
    # O redirecionamento posterior altera o conteúdo sem recriar esse inode.
    cp --archive --no-target-directory -- "$HOSTS_FILE" "$TEMP_HOSTS_FILE"

    # O programa awk abaixo armazena o arquivo para poder consolidar todas as
    # entradas 127.0.1.1 em uma única linha na posição da primeira ocorrência.
    #
    # -v passa valores do Bash como dados, não como código awk.
    # - ORIGINAL_LINES preserva todas as linhas não administradas pelo módulo.
    # - LOCAL_LINES marca somente registros cujo primeiro campo é 127.0.1.1.
    # - aliases diferentes dos hostnames antigo e novo são preservados sem
    #   repetição e na ordem em que aparecem.
    # - comentários das linhas consolidadas são mantidos; comentários adicionais
    #   tornam-se linhas próprias logo depois da entrada canônica.
    # - o redirecionamento > grava exclusivamente no temporário validado.
    awk \
        -v TARGET="$TARGET_HOSTNAME" \
        -v OLD_ACTIVE="$CURRENT_ACTIVE_HOSTNAME" \
        -v OLD_STATIC="$CURRENT_STATIC_HOSTNAME" '
        {
            ORIGINAL_LINES[NR] = $0

            if ($1 == "127.0.1.1") {
                LOCAL_LINES[NR] = 1

                if (FIRST_LOCAL_LINE == 0) {
                    FIRST_LOCAL_LINE = NR
                }

                COMMENT_POSITION = index($0, "#")

                if (COMMENT_POSITION > 0) {
                    COMMENT_TEXT = substr($0, COMMENT_POSITION)

                    if (!(COMMENT_TEXT in SEEN_COMMENTS)) {
                        COMMENT_COUNT += 1
                        COMMENTS[COMMENT_COUNT] = COMMENT_TEXT
                        SEEN_COMMENTS[COMMENT_TEXT] = 1
                    }
                }

                for (FIELD_INDEX = 2; FIELD_INDEX <= NF; FIELD_INDEX += 1) {
                    FIELD_VALUE = $FIELD_INDEX

                    if (substr(FIELD_VALUE, 1, 1) == "#") {
                        break
                    }

                    if (FIELD_VALUE == TARGET) {
                        continue
                    }

                    if (FIELD_VALUE == OLD_ACTIVE) {
                        continue
                    }

                    if (FIELD_VALUE == OLD_STATIC) {
                        continue
                    }

                    if (!(FIELD_VALUE in SEEN_ALIASES)) {
                        ALIAS_COUNT += 1
                        ALIASES[ALIAS_COUNT] = FIELD_VALUE
                        SEEN_ALIASES[FIELD_VALUE] = 1
                    }
                }
            }
        }

        END {
            if (FIRST_LOCAL_LINE == 0) {
                for (LINE_INDEX = 1; LINE_INDEX <= NR; LINE_INDEX += 1) {
                    print ORIGINAL_LINES[LINE_INDEX]
                }

                printf "127.0.1.1\t%s\n", TARGET
                exit
            }

            for (LINE_INDEX = 1; LINE_INDEX <= NR; LINE_INDEX += 1) {
                if (LINE_INDEX == FIRST_LOCAL_LINE) {
                    printf "127.0.1.1\t%s", TARGET

                    for (ALIAS_INDEX = 1; ALIAS_INDEX <= ALIAS_COUNT; ALIAS_INDEX += 1) {
                        printf "\t%s", ALIASES[ALIAS_INDEX]
                    }

                    if (COMMENT_COUNT > 0) {
                        printf "\t%s", COMMENTS[1]
                    }

                    printf "\n"

                    for (COMMENT_INDEX = 2; COMMENT_INDEX <= COMMENT_COUNT; COMMENT_INDEX += 1) {
                        print COMMENTS[COMMENT_INDEX]
                    }
                } else if (!(LINE_INDEX in LOCAL_LINES)) {
                    print ORIGINAL_LINES[LINE_INDEX]
                }
            }
        }
    ' "$HOSTS_FILE" >"$TEMP_HOSTS_FILE"

    # A versão temporária precisa conter exatamente uma entrada administrada e
    # essa entrada deve registrar TARGET_HOSTNAME no segundo campo.
    TEMP_ENTRY_COUNT="$(awk '$1 == "127.0.1.1" { COUNT += 1 } END { print COUNT + 0 }' "$TEMP_HOSTS_FILE")"
    TEMP_TARGET_COUNT="$(
        awk -v TARGET="$TARGET_HOSTNAME" '
            $1 == "127.0.1.1" {
                if ($2 == TARGET) {
                    COUNT += 1
                }
            }

            END {
                print COUNT + 0
            }
        ' "$TEMP_HOSTS_FILE"
    )"

    if [[ "$TEMP_ENTRY_COUNT" != '1' ]]; then
        error "A versão temporária possui ${TEMP_ENTRY_COUNT} entradas 127.0.1.1."
        return 1
    fi

    if [[ "$TEMP_TARGET_COUNT" != '1' ]]; then
        error "A versão temporária não registra corretamente ${TARGET_HOSTNAME}."
        return 1
    fi

    success 'Nova versão de /etc/hosts preparada e validada.'
    return 0
}


###############################################################################
# EXECUTAR A TRANSAÇÃO
###############################################################################

if [[ "$HOSTNAME_CHANGE_REQUIRED" -eq 0 ]]; then
    if [[ "$HOSTS_CHANGE_REQUIRED" -eq 0 ]]; then
        success 'O hostname e /etc/hosts já estão configurados corretamente.'
        info 'Nenhuma escrita e nenhum backup foram necessários.'
    fi
fi

if [[ "$HOSTNAME_CHANGE_REQUIRED" -eq 1 ]]; then
    create_verified_backups
else
    if [[ "$HOSTS_CHANGE_REQUIRED" -eq 1 ]]; then
        create_verified_backups
    fi
fi

# Preparar o arquivo antes de ativar a transação reduz o intervalo em que o
# sistema pode ficar parcialmente alterado. O original ainda não é modificado.
if [[ "$HOSTS_CHANGE_REQUIRED" -eq 1 ]]; then
    prepare_hosts_update
fi

if [[ "$BACKUPS_READY" -eq 1 ]]; then
    TRANSACTION_ACTIVE=1

    if [[ "$HOSTNAME_CHANGE_REQUIRED" -eq 1 ]]; then
        info "Alterando o hostname para '${TARGET_HOSTNAME}'..."

        # A flag é definida antes do comando porque uma falha pode ocorrer após
        # o serviço ter aplicado somente parte da solicitação.
        HOSTNAME_CHANGE_ATTEMPTED=1

        # --static atualiza o hostname persistente e /etc/hostname.
        # --transient atualiza o nome de execução do systemd e do kernel.
        # O comando set-hostname recebe TARGET_HOSTNAME como único parâmetro.
        # A ausência de --pretty é intencional: /etc/machine-info fica intacto.
        hostnamectl --static --transient set-hostname "$TARGET_HOSTNAME"

        CONFIGURATION_CHANGED=1
        success 'Hostnames estático e transiente atualizados.'
    fi

    if [[ "$HOSTS_CHANGE_REQUIRED" -eq 1 ]]; then
        info "Instalando a nova versão de ${HOSTS_FILE}..."

        # --force permite substituir o destino já validado sem interação.
        # --no-target-directory exige o caminho exato de destino.
        # -- encerra opções. Como origem e destino estão em /etc, mv realiza uma
        # renomeação atômica no mesmo sistema de arquivos em uma instalação Kali
        # convencional. Bind mounts podem recusar a operação e acionar rollback.
        mv --force --no-target-directory -- "$TEMP_HOSTS_FILE" "$HOSTS_FILE"
        TEMP_HOSTS_FILE=''

        CONFIGURATION_CHANGED=1
        success "Arquivo ${HOSTS_FILE} atualizado."
    fi
fi


###############################################################################
# LER E VALIDAR O ESTADO FINAL
###############################################################################

info 'Validando a configuração final...'

FINAL_ACTIVE_HOSTNAME="$(hostname)"
FINAL_STATIC_HOSTNAME="$(hostnamectl --static)"
FINAL_TRANSIENT_HOSTNAME="$(hostnamectl --transient)"
FINAL_FILE_HOSTNAME="$(awk 'NR == 1 { print; exit }' "$HOSTNAME_FILE")"
FINAL_FILE_LINE_COUNT="$(awk 'END { print NR }' "$HOSTNAME_FILE")"
FINAL_HOSTS_ENTRY="$(awk '$1 == "127.0.1.1" { print; exit }' "$HOSTS_FILE")"
FINAL_HOSTS_ENTRY_COUNT="$(awk '$1 == "127.0.1.1" { COUNT += 1 } END { print COUNT + 0 }' "$HOSTS_FILE")"
FINAL_HOSTS_TARGET_COUNT="$(
    awk -v TARGET="$TARGET_HOSTNAME" '
        $1 == "127.0.1.1" {
            if ($2 == TARGET) {
                COUNT += 1
            }
        }

        END {
            print COUNT + 0
        }
    ' "$HOSTS_FILE"
)"

# Cada falha retorna 1 da função principal implícita do script. Como a transação
# ainda está ativa, o trap ERR executará o rollback antes de encerrar.
if [[ "$FINAL_ACTIVE_HOSTNAME" != "$TARGET_HOSTNAME" ]]; then
    error "Hostname ativo inesperado: ${FINAL_ACTIVE_HOSTNAME:-vazio}"
    trigger_transaction_error
fi

success 'Hostname ativo validado.'

if [[ "$FINAL_STATIC_HOSTNAME" != "$TARGET_HOSTNAME" ]]; then
    error "Hostname estático inesperado: ${FINAL_STATIC_HOSTNAME:-vazio}"
    trigger_transaction_error
fi

success 'Hostname estático validado.'

if [[ "$FINAL_TRANSIENT_HOSTNAME" != "$TARGET_HOSTNAME" ]]; then
    error "Hostname transiente inesperado: ${FINAL_TRANSIENT_HOSTNAME:-vazio}"
    trigger_transaction_error
fi

success 'Hostname transiente validado.'

if [[ "$FINAL_FILE_LINE_COUNT" != '1' ]]; then
    error "${HOSTNAME_FILE} deve possuir exatamente uma linha."
    trigger_transaction_error
fi

if [[ "$FINAL_FILE_HOSTNAME" != "$TARGET_HOSTNAME" ]]; then
    error "Conteúdo inesperado em ${HOSTNAME_FILE}: ${FINAL_FILE_HOSTNAME:-vazio}"
    trigger_transaction_error
fi

success "Arquivo ${HOSTNAME_FILE} validado."

if [[ "$FINAL_HOSTS_ENTRY_COUNT" != '1' ]]; then
    error "${HOSTS_FILE} possui ${FINAL_HOSTS_ENTRY_COUNT} entradas 127.0.1.1."
    trigger_transaction_error
fi

if [[ "$FINAL_HOSTS_TARGET_COUNT" != '1' ]]; then
    error "${HOSTS_FILE} não registra ${TARGET_HOSTNAME} como hostname canônico."
    trigger_transaction_error
fi

success "Arquivo ${HOSTS_FILE} validado."

# A transação só deixa de exigir rollback depois que todas as validações passam.
TRANSACTION_ACTIVE=0


###############################################################################
# RESUMO FINAL
###############################################################################

if [[ "$CONFIGURATION_CHANGED" -eq 1 ]]; then
    FINAL_STATUS='ALTERADO COM SUCESSO'
    BACKUP_SUMMARY="$BACKUP_DIR"
else
    FINAL_STATUS='JÁ CONFIGURADO'
    BACKUP_SUMMARY='Não necessário'
fi

printf '\n'
printf '%s\n' '============================================================'
printf '%s\n' '                 MÓDULO 02 CONCLUÍDO'
printf '%s\n' '============================================================'
printf '\n'

# %-24s reserva 24 posições e alinha os rótulos à esquerda. O segundo %s exibe
# o valor sem interpretá-lo como formato, mantendo o resumo seguro e legível.
printf '%-24s %s\n' 'Hostname anterior......:' "$CURRENT_ACTIVE_HOSTNAME"
printf '%-24s %s\n' 'Hostname ativo.........:' "$FINAL_ACTIVE_HOSTNAME"
printf '%-24s %s\n' 'Hostname estático......:' "$FINAL_STATIC_HOSTNAME"
printf '%-24s %s\n' 'Hostname transiente....:' "$FINAL_TRANSIENT_HOSTNAME"
printf '%-24s %s\n' 'Arquivo hostname.......:' "$FINAL_FILE_HOSTNAME"
printf '%-24s %s\n' 'Entrada hosts..........:' "$FINAL_HOSTS_ENTRY"
printf '%-24s %s\n' 'Backup.................:' "$BACKUP_SUMMARY"
printf '%-24s %s\n' 'Rollback...............:' "$ROLLBACK_RESULT"
printf '%-24s %s\n' 'Status.................:' "$FINAL_STATUS"
printf '%-24s %s\n' 'Próximo módulo.........:' "$NEXT_MODULE"
printf '\n'

warning 'Abra um novo terminal para atualizar o hostname exibido pelo prompt.'
warning 'Alguns aplicativos gráficos podem exigir logout ou reinicialização.'
printf '\n'
