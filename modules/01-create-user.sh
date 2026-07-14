#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 01
# NOME..........: Criação do usuário principal
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux
# VERSÃO........: 1.0
#
# DESCRIÇÃO
#
# Este módulo cria e configura o usuário principal que será utilizado no
# ambiente Kali Linux.
#
# CONFIGURAÇÃO PADRÃO
#
# Usuário........: diogo
# Nome completo..: Diogo Frota
# Diretório Home.: /home/diogo
# Shell padrão...: /bin/bash
# Grupo admin....: sudo
#
# O QUE ESTE SCRIPT FAZ
#
# - Confirma que está sendo executado como root.
# - Valida o nome do usuário.
# - Verifica se o shell Bash está disponível.
# - Verifica se o grupo sudo existe.
# - Cria o usuário, caso ele ainda não exista.
# - Cria e configura o diretório Home.
# - Define o Bash como shell padrão.
# - Adiciona o usuário ao grupo sudo.
# - Verifica a configuração final.
# - Exibe o hostname atual no resumo.
#
# O QUE ESTE SCRIPT NÃO FAZ
#
# - Não remove o usuário parallels.
# - Não altera o hostname.
# - Não copia arquivos de outro usuário.
# - Não instala ferramentas.
# - Não atualiza o sistema.
#
# EXECUÇÃO
#
# sudo ./modules/01-create-user.sh
###############################################################################


###############################################################################
# CONFIGURAÇÕES DE SEGURANÇA DO BASH
###############################################################################

# -E
# Faz com que o tratamento de erros seja herdado por funções e subshells.
#
# -e
# Encerra o script quando um comando retorna erro.
#
# -u
# Encerra o script quando uma variável não definida é utilizada.
#
# -o pipefail
# Faz uma sequência com pipe falhar caso qualquer comando dela apresente erro.
set -Eeuo pipefail


###############################################################################
# CONFIGURAÇÕES DO USUÁRIO
###############################################################################

# Nome utilizado para entrar no sistema.
#
# Por padrão, nomes de usuários Linux devem utilizar letras minúsculas,
# números, hífen ou sublinhado.
USERNAME="diogo"

# Nome completo ou nome descritivo do usuário.
FULL_NAME="Diogo Frota"

# Diretório pessoal do usuário.
HOME_DIR="/home/${USERNAME}"

# Shell iniciado quando o usuário abrir um terminal.
DEFAULT_SHELL="/bin/bash"

# Grupo administrativo utilizado pelo Kali e pelo Debian.
ADMIN_GROUP="sudo"


###############################################################################
# INFORMAÇÕES DO SISTEMA
###############################################################################

# Captura o hostname atual da máquina.
#
# Não usamos a variável HOSTNAME diretamente porque ela já pode existir no
# ambiente do Bash. Um nome próprio evita conflitos.
MACHINE_HOSTNAME="$(hostname)"


###############################################################################
# CORES DAS MENSAGENS
###############################################################################

# Os códigos ANSI abaixo alteram as cores do texto no terminal.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'

# NC significa No Color.
# Retorna o terminal para a cor padrão.
NC='\033[0m'


###############################################################################
# FUNÇÕES DE MENSAGEM
###############################################################################

# Exibe uma mensagem informativa.
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Exibe uma mensagem de sucesso.
success() {
    echo -e "${GREEN}[ OK ]${NC} $*"
}

# Exibe um aviso.
warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Exibe uma mensagem de erro no fluxo de erro padrão.
error() {
    echo -e "${RED}[ERRO]${NC} $*" >&2
}


###############################################################################
# TRATAMENTO DE ERROS
###############################################################################

# Esta função é chamada automaticamente quando um comando apresenta erro.
tratar_erro() {
    # Guarda imediatamente o código de saída do comando que falhou.
    local codigo_saida=$?

    echo
    error "O módulo encontrou um erro."
    error "Comando executado: ${BASH_COMMAND}"
    error "Linha aproximada: ${BASH_LINENO[0]}"
    error "Código de saída: ${codigo_saida}"
    echo

    exit "$codigo_saida"
}

# ERR é um evento interno do Bash acionado quando um comando falha.
trap tratar_erro ERR


###############################################################################
# BANNER INICIAL
###############################################################################

clear

echo
echo "============================================================"
echo "            KALI SETUP - MÓDULO 01"
echo "             Criação do Usuário"
echo "============================================================"
echo

info "Hostname atual: ${MACHINE_HOSTNAME}"
info "Usuário que será configurado: ${USERNAME}"
info "Nome completo: ${FULL_NAME}"
info "Diretório pessoal: ${HOME_DIR}"
info "Shell padrão: ${DEFAULT_SHELL}"
echo


###############################################################################
# VERIFICAR PRIVILÉGIOS ADMINISTRATIVOS
###############################################################################

info "Verificando privilégios administrativos..."

# EUID contém o identificador efetivo do usuário que executa o script.
#
# O usuário root possui sempre o UID 0.
#
# A criação e modificação de usuários altera arquivos protegidos, como:
#
# /etc/passwd
# /etc/shadow
# /etc/group
#
# Por isso, este módulo precisa ser executado com sudo.
if [[ "$EUID" -ne 0 ]]; then
    error "Este módulo precisa ser executado com privilégios administrativos."
    echo
    echo "Execute:"
    echo
    echo "    sudo ./modules/01-create-user.sh"
    echo
    exit 1
fi

success "Privilégios administrativos confirmados."


###############################################################################
# VALIDAR O NOME DO USUÁRIO
###############################################################################

info "Validando o nome do usuário..."

# Esta expressão regular exige que:
#
# - o nome comece com uma letra minúscula;
# - os demais caracteres sejam letras minúsculas, números, hífen ou sublinhado.
if [[ ! "$USERNAME" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    error "O nome de usuário '${USERNAME}' não possui um formato válido."
    exit 1
fi

success "Nome de usuário validado."


###############################################################################
# VERIFICAR O SHELL
###############################################################################

info "Verificando o shell padrão..."

# A opção -x testa se o arquivo existe e possui permissão de execução.
if [[ ! -x "$DEFAULT_SHELL" ]]; then
    error "O shell '${DEFAULT_SHELL}' não existe ou não é executável."
    exit 1
fi

success "Shell encontrado: ${DEFAULT_SHELL}"


###############################################################################
# VERIFICAR O GRUPO ADMINISTRATIVO
###############################################################################

info "Verificando o grupo administrativo..."

# getent consulta bancos de dados do sistema.
#
# O comando abaixo consulta se o grupo sudo está registrado no sistema.
if ! getent group "$ADMIN_GROUP" >/dev/null 2>&1; then
    error "O grupo administrativo '${ADMIN_GROUP}' não foi encontrado."
    exit 1
fi

success "Grupo administrativo encontrado: ${ADMIN_GROUP}"


###############################################################################
# VERIFICAR SE O USUÁRIO JÁ EXISTE
###############################################################################

info "Verificando se o usuário '${USERNAME}' já existe..."

# O comando id retorna sucesso quando o usuário existe.
if id "$USERNAME" >/dev/null 2>&1; then
    warning "O usuário '${USERNAME}' já existe."
    warning "O módulo verificará e corrigirá sua configuração."

else
    ###########################################################################
    # CRIAR O USUÁRIO
    ###########################################################################

    info "Criando o usuário '${USERNAME}'..."

    # adduser é uma ferramenta de alto nível para criação de usuários.
    #
    # Ela:
    #
    # - cria a conta;
    # - cria o diretório Home;
    # - copia os arquivos padrão de /etc/skel;
    # - solicita uma senha;
    # - define permissões adequadas.
    #
    # --home
    # Define explicitamente o diretório pessoal.
    #
    # --shell
    # Define o shell padrão.
    #
    # --gecos
    # Define o nome completo sem fazer perguntas adicionais sobre telefone,
    # sala ou outras informações antigas do campo GECOS.
    adduser \
        --home "$HOME_DIR" \
        --shell "$DEFAULT_SHELL" \
        --gecos "$FULL_NAME" \
        "$USERNAME"

    success "Usuário '${USERNAME}' criado."
fi


###############################################################################
# GARANTIR QUE O DIRETÓRIO HOME EXISTA
###############################################################################

info "Verificando o diretório pessoal..."

if [[ ! -d "$HOME_DIR" ]]; then
    warning "O diretório '${HOME_DIR}' não foi encontrado."
    info "Criando o diretório pessoal..."

    # mkdir -p cria o diretório e não apresenta erro se ele já existir.
    mkdir -p "$HOME_DIR"

    success "Diretório pessoal criado."
else
    success "Diretório pessoal encontrado: ${HOME_DIR}"
fi


###############################################################################
# CONFIGURAR O PROPRIETÁRIO DO DIRETÓRIO HOME
###############################################################################

info "Verificando o proprietário do diretório pessoal..."

# chown altera o proprietário e o grupo.
#
# O formato utilizado é:
#
# usuário:grupo
#
# A opção -R aplica a alteração de forma recursiva aos arquivos existentes
# dentro do diretório.
chown -R "${USERNAME}:${USERNAME}" "$HOME_DIR"

success "Proprietário do diretório pessoal configurado."


###############################################################################
# DEFINIR O SHELL PADRÃO
###############################################################################

info "Configurando o shell padrão..."

# usermod modifica uma conta existente.
#
# A opção -s define o shell de login.
usermod -s "$DEFAULT_SHELL" "$USERNAME"

success "Shell padrão definido como ${DEFAULT_SHELL}"


###############################################################################
# ADICIONAR O USUÁRIO AO GRUPO SUDO
###############################################################################

info "Verificando acesso administrativo..."

# id -nG mostra os nomes dos grupos do usuário.
#
# grep -qw procura o nome exato do grupo.
if id -nG "$USERNAME" | grep -qw "$ADMIN_GROUP"; then
    success "O usuário '${USERNAME}' já pertence ao grupo '${ADMIN_GROUP}'."

else
    info "Adicionando '${USERNAME}' ao grupo '${ADMIN_GROUP}'..."

    # usermod -aG adiciona o usuário a um grupo complementar.
    #
    # -a significa append, ou adicionar.
    #
    # -G indica os grupos complementares.
    #
    # É importante utilizar -a e -G juntos. Sem -a, outros grupos
    # complementares do usuário poderiam ser removidos.
    usermod -aG "$ADMIN_GROUP" "$USERNAME"

    success "Usuário adicionado ao grupo '${ADMIN_GROUP}'."
fi


###############################################################################
# VERIFICAÇÃO FINAL DA CONTA
###############################################################################

info "Verificando a configuração final da conta..."

# Busca a entrada completa do usuário no banco de contas.
USER_ENTRY="$(getent passwd "$USERNAME")"

if [[ -z "$USER_ENTRY" ]]; then
    error "Não foi possível localizar a conta '${USERNAME}'."
    exit 1
fi

# Obtém o UID numérico.
USER_UID="$(id -u "$USERNAME")"

# Obtém o nome do grupo principal.
PRIMARY_GROUP="$(id -gn "$USERNAME")"

# Obtém todos os grupos aos quais o usuário pertence.
USER_GROUPS="$(id -nG "$USERNAME")"

# O arquivo lógico passwd utiliza campos separados por dois-pontos.
#
# Campo 6: diretório Home.
# Campo 7: shell de login.
REGISTERED_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
REGISTERED_SHELL="$(getent passwd "$USERNAME" | cut -d: -f7)"


###############################################################################
# VALIDAR O DIRETÓRIO HOME REGISTRADO
###############################################################################

if [[ "$REGISTERED_HOME" != "$HOME_DIR" ]]; then
    error "O diretório Home registrado não corresponde ao esperado."
    error "Esperado: ${HOME_DIR}"
    error "Encontrado: ${REGISTERED_HOME}"
    exit 1
fi

success "Diretório Home registrado corretamente."


###############################################################################
# VALIDAR O SHELL REGISTRADO
###############################################################################

if [[ "$REGISTERED_SHELL" != "$DEFAULT_SHELL" ]]; then
    error "O shell registrado não corresponde ao esperado."
    error "Esperado: ${DEFAULT_SHELL}"
    error "Encontrado: ${REGISTERED_SHELL}"
    exit 1
fi

success "Shell registrado corretamente."


###############################################################################
# VALIDAR O GRUPO SUDO
###############################################################################

if ! id -nG "$USERNAME" | grep -qw "$ADMIN_GROUP"; then
    error "O usuário '${USERNAME}' não pertence ao grupo '${ADMIN_GROUP}'."
    exit 1
fi

success "Acesso administrativo confirmado pelo grupo '${ADMIN_GROUP}'."


###############################################################################
# RESUMO FINAL
###############################################################################

echo
echo "============================================================"
echo "                 MÓDULO 01 CONCLUÍDO"
echo "============================================================"
echo

printf "%-18s %s\n" "Hostname........:" "$MACHINE_HOSTNAME"
printf "%-18s %s\n" "Usuário.........:" "$USERNAME"
printf "%-18s %s\n" "Nome............:" "$FULL_NAME"
printf "%-18s %s\n" "UID.............:" "$USER_UID"
printf "%-18s %s\n" "Grupo principal.:" "$PRIMARY_GROUP"
printf "%-18s %s\n" "Grupos..........:" "$USER_GROUPS"
printf "%-18s %s\n" "Home............:" "$REGISTERED_HOME"
printf "%-18s %s\n" "Shell...........:" "$REGISTERED_SHELL"

echo
printf "%-18s %s\n" "Status..........:" "SUCESSO"

echo
printf "%-18s %s\n" "Próximo módulo..:" "02-hostname.sh"
echo
