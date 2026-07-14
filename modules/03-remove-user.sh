#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 03
# NOME..........: Remoção segura do usuário legado
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Remover de forma controlada o usuário legado "parallels", preservando o
# usuário principal "diogo" e garantindo que o sistema continue administrável.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma execução com sudo.
# 2. Confirma que SUDO_USER é diogo.
# 3. Verifica se diogo existe, possui /home/diogo e pertence ao grupo sudo.
# 4. Verifica se parallels existe.
# 5. Valida que o home de parallels é exatamente /home/parallels.
# 6. Solicita confirmação literal digitando REMOVER.
# 7. Encerra processos do usuário parallels.
# 8. Executa deluser --remove-home parallels.
# 9. Remove o grupo residual parallels somente se ele estiver vazio.
# 10. Confirma que parallels e /home/parallels foram removidos.
#
# RISCOS CONTROLADOS
#
# Remover usuários é uma ação destrutiva. Um erro de variável, um usuário alvo
# incorreto ou um home inesperado pode apagar dados errados. Por isso o módulo
# valida o usuário principal, impede remoção de root, impede que os usuários
# principal e removido sejam iguais, exige home exato e pede confirmação manual.
###############################################################################


###############################################################################
# CONFIGURAÇÕES DE SEGURANÇA DO BASH
###############################################################################

set -Eeuo pipefail

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH

LC_ALL='C'
export LC_ALL

umask 077


###############################################################################
# CONFIGURAÇÃO DO MÓDULO
###############################################################################

readonly PRIMARY_USER='diogo'
readonly PRIMARY_GROUP='diogo'
readonly PRIMARY_HOME_EXPECTED='/home/diogo'
readonly ADMIN_GROUP='sudo'

readonly REMOVE_USER='parallels'
readonly REMOVE_HOME_EXPECTED='/home/parallels'

readonly NEXT_MODULE='04-configure-api-keys.sh'


###############################################################################
# ESTADO DA EXECUÇÃO
###############################################################################

REAL_USER=''
PRIMARY_HOME_FOUND=''
REMOVE_HOME_FOUND=''
REMOVAL_STATUS='Não executado'
GROUP_STATUS='Não avaliado'
FINAL_STATUS='PENDENTE'


###############################################################################
# CORES E MENSAGENS
###############################################################################

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

info() {
    printf '%b[INFO]%b %s\n' "$BLUE" "$NC" "$*"
}

success() {
    printf '%b[ OK ]%b %s\n' "$GREEN" "$NC" "$*"
}

warning() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*"
}

error() {
    printf '%b[ERRO]%b %s\n' "$RED" "$NC" "$*" >&2
}


###############################################################################
# TRATAMENTO DE ERROS
###############################################################################

handle_error() {
    local codigo_saida="$?"
    local comando_falhou="${BASH_COMMAND}"
    local linha_aproximada="${BASH_LINENO[0]:-${LINENO}}"

    trap - ERR

    printf '\n' >&2
    error "O módulo encontrou um erro."
    error "Comando executado: ${comando_falhou}"
    error "Linha aproximada: ${linha_aproximada}"
    error "Código de saída: ${codigo_saida}"
    printf '\n' >&2

    exit "$codigo_saida"
}

trap handle_error ERR


###############################################################################
# BANNER
###############################################################################

print_banner() {
    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' '            KALI SETUP - MÓDULO 03'
    printf '%s\n' '          Remoção do Usuário Legado'
    printf '%s\n' '============================================================'
    printf '\n'
}


###############################################################################
# COMANDOS OBRIGATÓRIOS
###############################################################################

require_command() {
    local comando="$1"

    if command -v "$comando" >/dev/null 2>&1; then
        return 0
    fi

    error "Comando obrigatório não encontrado: ${comando}"
    exit 1
}

validate_required_commands() {
    info "Validando comandos necessários..."

    require_command delgroup
    require_command deluser
    require_command getent
    require_command id
    require_command pgrep
    require_command pkill
    require_command sleep
    require_command stat

    success "Comandos obrigatórios encontrados."
}


###############################################################################
# FUNÇÕES DE CONSULTA
###############################################################################

user_exists() {
    local usuario="$1"

    if getent passwd "$usuario" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

group_exists() {
    local grupo="$1"

    if getent group "$grupo" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

get_home_from_passwd() {
    local usuario="$1"
    local entrada_passwd=''
    local nome=''
    local senha=''
    local uid=''
    local gid=''
    local gecos=''
    local home=''
    local shell=''

    if entrada_passwd="$(getent passwd "$usuario")"; then
        IFS=':' read -r nome senha uid gid gecos home shell <<< "$entrada_passwd"
        printf '%s\n' "$home"
        return 0
    fi

    return 1
}

user_is_in_group() {
    local usuario="$1"
    local grupo="$2"
    local grupos_usuario=''

    if grupos_usuario="$(id -nG "$usuario")"; then
        case " ${grupos_usuario} " in
            *" ${grupo} "*)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    fi

    return 1
}


###############################################################################
# VALIDAR EXECUÇÃO E USUÁRIO PRINCIPAL
###############################################################################

validate_execution_context() {
    info "Verificando privilégios administrativos..."

    if [[ "$EUID" -ne 0 ]]; then
        error "Este módulo precisa ser executado com sudo."
        error "Use: sudo ./modules/03-remove-user.sh"
        exit 1
    fi

    if [[ -z "${SUDO_USER:-}" ]]; then
        error "SUDO_USER não está definido. Execute com sudo a partir de ${PRIMARY_USER}."
        exit 1
    fi

    REAL_USER="$SUDO_USER"

    if [[ "$REAL_USER" != "$PRIMARY_USER" ]]; then
        error "Usuário real recusado: esperado ${PRIMARY_USER}, encontrado ${REAL_USER}."
        exit 1
    fi

    success "Execução com sudo confirmada para o usuário real ${REAL_USER}."
}

validate_user_safety_rules() {
    info "Validando regras de segurança dos usuários..."

    if [[ "$REMOVE_USER" == 'root' ]]; then
        error "Remoção de root é proibida."
        exit 1
    fi

    if [[ "$PRIMARY_USER" == "$REMOVE_USER" ]]; then
        error "Usuário principal e usuário removido não podem ser iguais."
        exit 1
    fi

    if user_exists "$PRIMARY_USER"; then
        PRIMARY_HOME_FOUND="$(get_home_from_passwd "$PRIMARY_USER")"
    else
        error "Usuário principal não existe: ${PRIMARY_USER}"
        exit 1
    fi

    if [[ "$PRIMARY_HOME_FOUND" != "$PRIMARY_HOME_EXPECTED" ]]; then
        error "Home de ${PRIMARY_USER} inesperado: ${PRIMARY_HOME_FOUND}"
        exit 1
    fi

    if [[ -d "$PRIMARY_HOME_EXPECTED" ]]; then
        :
    else
        error "Diretório home de ${PRIMARY_USER} não encontrado: ${PRIMARY_HOME_EXPECTED}"
        exit 1
    fi

    if user_is_in_group "$PRIMARY_USER" "$ADMIN_GROUP"; then
        success "${PRIMARY_USER} pertence ao grupo ${ADMIN_GROUP}."
    else
        error "${PRIMARY_USER} não pertence ao grupo ${ADMIN_GROUP}."
        exit 1
    fi
}


###############################################################################
# VALIDAR USUÁRIO A SER REMOVIDO
###############################################################################

validate_removed_user() {
    info "Verificando usuário que será removido..."

    if user_exists "$REMOVE_USER"; then
        REMOVE_HOME_FOUND="$(get_home_from_passwd "$REMOVE_USER")"
    else
        warning "Usuário ${REMOVE_USER} não existe. Nada será removido."
        REMOVAL_STATUS='Usuário já ausente'
        return 1
    fi

    if [[ "$REMOVE_HOME_FOUND" != "$REMOVE_HOME_EXPECTED" ]]; then
        error "Home de ${REMOVE_USER} inesperado: ${REMOVE_HOME_FOUND}"
        error "Remoção recusada para evitar apagar caminho incorreto."
        exit 1
    fi

    if [[ -d "$REMOVE_HOME_EXPECTED" ]]; then
        success "Home de ${REMOVE_USER} confirmado: ${REMOVE_HOME_EXPECTED}"
    else
        warning "Home ${REMOVE_HOME_EXPECTED} não existe; deluser ainda será validado pelo sistema."
    fi

    return 0
}


###############################################################################
# CONFIRMAÇÃO MANUAL
###############################################################################

confirm_removal() {
    local resposta=''

    printf '\n'
    warning "Esta ação removerá o usuário ${REMOVE_USER} e seu home ${REMOVE_HOME_EXPECTED}."
    warning "Digite REMOVER para confirmar conscientemente."
    printf 'Confirmação: '

    if read -r resposta; then
        if [[ "$resposta" == 'REMOVER' ]]; then
            success "Confirmação recebida."
            return 0
        fi
    fi

    error "Confirmação inválida. Nenhuma remoção foi executada."
    exit 1
}


###############################################################################
# ENCERRAR PROCESSOS DO USUÁRIO REMOVIDO
###############################################################################

terminate_removed_user_processes() {
    info "Verificando processos do usuário ${REMOVE_USER}..."

    if pgrep -u "$REMOVE_USER" >/dev/null 2>&1; then
        warning "Processos encontrados. Enviando TERM para encerramento limpo."
        pkill -TERM -u "$REMOVE_USER"
        sleep 3

        if pgrep -u "$REMOVE_USER" >/dev/null 2>&1; then
            warning "Ainda há processos ativos. Enviando KILL como último recurso."
            pkill -KILL -u "$REMOVE_USER"
            sleep 1
        fi

        if pgrep -u "$REMOVE_USER" >/dev/null 2>&1; then
            error "Não foi possível encerrar todos os processos de ${REMOVE_USER}."
            exit 1
        fi

        success "Processos de ${REMOVE_USER} encerrados."
    else
        success "Nenhum processo de ${REMOVE_USER} encontrado."
    fi
}


###############################################################################
# REMOVER USUÁRIO E GRUPO RESIDUAL
###############################################################################

remove_legacy_user() {
    info "Removendo usuário ${REMOVE_USER} com deluser --remove-home..."

    deluser --remove-home "$REMOVE_USER"
    REMOVAL_STATUS='Removido'

    success "Comando de remoção concluído."
}

group_is_empty() {
    local grupo="$1"
    local linha_grupo=''
    local nome=''
    local senha=''
    local gid_grupo=''
    local membros=''
    local entrada_passwd=''
    local usuario=''
    local senha_usuario=''
    local uid_usuario=''
    local gid_usuario=''
    local gecos=''
    local home=''
    local shell=''

    if linha_grupo="$(getent group "$grupo")"; then
        IFS=':' read -r nome senha gid_grupo membros <<< "$linha_grupo"

        if [[ -n "$membros" ]]; then
            return 1
        fi

        while IFS= read -r entrada_passwd; do
            IFS=':' read -r usuario senha_usuario uid_usuario gid_usuario gecos home shell <<< "$entrada_passwd"
            if [[ "$gid_usuario" == "$gid_grupo" ]]; then
                return 1
            fi
        done < <(getent passwd)

        return 0
    fi

    return 1
}

remove_residual_group_if_empty() {
    info "Verificando grupo residual ${REMOVE_USER}..."

    if group_exists "$REMOVE_USER"; then
        if group_is_empty "$REMOVE_USER"; then
            delgroup "$REMOVE_USER"
            GROUP_STATUS='Grupo residual removido'
            success "Grupo residual ${REMOVE_USER} removido."
        else
            GROUP_STATUS='Grupo preservado: ainda possui membros'
            warning "Grupo ${REMOVE_USER} não está vazio; preservado."
        fi
    else
        GROUP_STATUS='Grupo ausente'
        success "Grupo residual ${REMOVE_USER} não existe."
    fi
}


###############################################################################
# VALIDAÇÃO FINAL
###############################################################################

validate_final_state() {
    info "Validando estado final..."

    if user_exists "$REMOVE_USER"; then
        error "Usuário ${REMOVE_USER} ainda existe após a remoção."
        exit 1
    fi

    if [[ -e "$REMOVE_HOME_EXPECTED" ]]; then
        error "Home ${REMOVE_HOME_EXPECTED} ainda existe após a remoção."
        exit 1
    fi

    if user_exists "$PRIMARY_USER"; then
        :
    else
        error "Usuário principal ${PRIMARY_USER} não existe após a remoção."
        exit 1
    fi

    if [[ -d "$PRIMARY_HOME_EXPECTED" ]]; then
        :
    else
        error "Home de ${PRIMARY_USER} desapareceu: ${PRIMARY_HOME_EXPECTED}"
        exit 1
    fi

    if user_is_in_group "$PRIMARY_USER" "$ADMIN_GROUP"; then
        FINAL_STATUS='OK'
        success "Usuário principal ${PRIMARY_USER} permanece funcional."
    else
        error "${PRIMARY_USER} perdeu associação ao grupo ${ADMIN_GROUP}."
        exit 1
    fi
}


###############################################################################
# RESUMO FINAL
###############################################################################

print_summary() {
    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' '             MÓDULO 03 CONCLUÍDO'
    printf '%s\n' '============================================================'
    printf '\n'
    printf '%-18s: %s\n' 'Usuário mantido' "$PRIMARY_USER"
    printf '%-18s: %s\n' 'Usuário removido' "$REMOVE_USER"
    printf '%-18s: %s\n' 'Home removido' "$REMOVE_HOME_EXPECTED"
    printf '%-18s: %s\n' 'Status remoção' "$REMOVAL_STATUS"
    printf '%-18s: %s\n' 'Grupo residual' "$GROUP_STATUS"
    printf '%-18s: %s\n' 'Status' "$FINAL_STATUS"
    printf '%-18s: %s\n' 'Próximo módulo' "$NEXT_MODULE"
    printf '\n'
}


###############################################################################
# EXECUÇÃO PRINCIPAL
###############################################################################

main() {
    print_banner

    info "Objetivo: remover apenas o usuário legado ${REMOVE_USER}."
    warning "Esta ação é destrutiva e exige confirmação literal antes da remoção."
    printf '\n'

    validate_required_commands
    validate_execution_context
    validate_user_safety_rules

    if validate_removed_user; then
        confirm_removal
        terminate_removed_user_processes
        remove_legacy_user
        remove_residual_group_if_empty
    else
        remove_residual_group_if_empty
    fi

    validate_final_state
    print_summary
}

main "$@"
