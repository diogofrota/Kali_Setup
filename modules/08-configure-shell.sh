#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 08
# NOME..........: Configuração do shell
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 1.0
#
# OBJETIVO
#
# Criar uma configuração de shell segura e reutilizável para o usuário real,
# adicionando diretórios de ferramentas ao PATH, aliases úteis e aliases para
# conflitos conhecidos de nomes, como httpx e fd/fdfind.
#
# FLUXO DE EXECUÇÃO
#
# 1. Confirma privilégios administrativos.
# 2. Descobre usuário e home reais.
# 3. Cria ~/.config/kali-setup/shell.sh.
# 4. Escreve entradas idempotentes de PATH para ~/.local/bin, ~/go/bin e
#    ~/.cargo/bin.
# 5. Escreve aliases operacionais e aliases contra conflitos de nomes.
# 6. Adiciona loader no .bashrc e no .zshrc quando aplicável.
#
# RISCOS CONTROLADOS
#
# Arquivos de shell podem executar comandos em todo terminal novo. Por isso o
# módulo não insere secrets, cria backups dos rc files e recusa links simbólicos.
###############################################################################

set -Eeuo pipefail
umask 077

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
LC_ALL='C'
export LC_ALL

MODULE_NAME='08-configure-shell'
NEXT_MODULE='09-configure-git.sh'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"; pwd -P)"
PROJECT_ROOT="$(dirname -- "$SCRIPT_DIR")"

# shellcheck source=../lib/common.sh
source "${PROJECT_ROOT}/lib/common.sh"

trap 'kali_setup_handle_error; exit $?' ERR

UPDATED=0
EXISTING=0
SKIPPED=0
FAILED=0
LOG_FILE=''
REAL_USER=''
REAL_HOME=''
SHELL_CONFIG=''

print_banner() {
    printf '\n%s\n%s\n%s\n%s\n\n' \
        '============================================================' \
        '            KALI SETUP - MÓDULO 08' \
        '              Configuração do Shell' \
        '============================================================'
}

write_shell_config() {
    SHELL_CONFIG="${REAL_HOME}/.config/kali-setup/shell.sh"
    ensure_directory "${REAL_HOME}/.config/kali-setup" '700' "$REAL_USER" "$REAL_USER"

    if [[ -L "$SHELL_CONFIG" ]]; then
        die "shell.sh é link simbólico; recusado."
    fi

    : > "$SHELL_CONFIG"
    printf '%s\n' '# KALI SETUP - Configuração de shell sem secrets' >> "$SHELL_CONFIG"
    printf '\n' >> "$SHELL_CONFIG"
    printf '%s\n' 'case ":$PATH:" in' >> "$SHELL_CONFIG"
    printf '%s\n' '    *":$HOME/.local/bin:"*) ;;' >> "$SHELL_CONFIG"
    printf '%s\n' '    *) PATH="$HOME/.local/bin:$PATH" ;;' >> "$SHELL_CONFIG"
    printf '%s\n' 'esac' >> "$SHELL_CONFIG"
    printf '\n' >> "$SHELL_CONFIG"
    printf '%s\n' 'case ":$PATH:" in' >> "$SHELL_CONFIG"
    printf '%s\n' '    *":$HOME/go/bin:"*) ;;' >> "$SHELL_CONFIG"
    printf '%s\n' '    *) PATH="$HOME/go/bin:$PATH" ;;' >> "$SHELL_CONFIG"
    printf '%s\n' 'esac' >> "$SHELL_CONFIG"
    printf '\n' >> "$SHELL_CONFIG"
    printf '%s\n' 'case ":$PATH:" in' >> "$SHELL_CONFIG"
    printf '%s\n' '    *":$HOME/.cargo/bin:"*) ;;' >> "$SHELL_CONFIG"
    printf '%s\n' '    *) PATH="$HOME/.cargo/bin:$PATH" ;;' >> "$SHELL_CONFIG"
    printf '%s\n' 'esac' >> "$SHELL_CONFIG"
    printf '\n' >> "$SHELL_CONFIG"
    printf '%s\n' 'export PATH' >> "$SHELL_CONFIG"
    printf '%s\n' 'export HISTSIZE=50000' >> "$SHELL_CONFIG"
    printf '%s\n' 'export HISTFILESIZE=100000' >> "$SHELL_CONFIG"
    printf '%s\n' 'export HISTCONTROL=ignoreboth:erasedups' >> "$SHELL_CONFIG"
    printf '\n' >> "$SHELL_CONFIG"
    printf '%s\n' "alias ll='ls -lah'" >> "$SHELL_CONFIG"
    printf '%s\n' "alias la='ls -A'" >> "$SHELL_CONFIG"
    printf '%s\n' "alias lt='ls -lahtr'" >> "$SHELL_CONFIG"
    printf '%s\n' "alias ports='ss -tulpen'" >> "$SHELL_CONFIG"
    printf '%s\n' "alias myip-local='ip -br addr'" >> "$SHELL_CONFIG"
    printf '%s\n' "alias update-kali-setup='install.sh --list'" >> "$SHELL_CONFIG"
    printf '%s\n' "alias check-tools='check-all-tools.sh'" >> "$SHELL_CONFIG"
    printf '\n' >> "$SHELL_CONFIG"
    printf '%s\n' '# KALI SETUP - aliases para conflitos conhecidos de nomes' >> "$SHELL_CONFIG"
    printf '%s\n' '# httpx também pode existir como cliente HTTP Python em alguns ambientes.' >> "$SHELL_CONFIG"
    printf '%s\n' '# Quando o binário do ProjectDiscovery existir em ~/go/bin, estes aliases' >> "$SHELL_CONFIG"
    printf '%s\n' '# garantem que o operador use a ferramenta de recon esperada no terminal.' >> "$SHELL_CONFIG"
    printf '%s\n' 'if [[ -x "$HOME/go/bin/httpx" ]]; then' >> "$SHELL_CONFIG"
    printf '%s\n' '    alias httpx="$HOME/go/bin/httpx"' >> "$SHELL_CONFIG"
    printf '%s\n' '    alias httpx-pd="$HOME/go/bin/httpx"' >> "$SHELL_CONFIG"
    printf '%s\n' 'fi' >> "$SHELL_CONFIG"
    printf '\n' >> "$SHELL_CONFIG"
    printf '%s\n' '# No Debian/Kali, o pacote fd-find costuma instalar o comando como fdfind.' >> "$SHELL_CONFIG"
    printf '%s\n' '# O alias fd só é criado quando fdfind existe e nenhum fd real está no PATH.' >> "$SHELL_CONFIG"
    printf '%s\n' 'if command -v fdfind >/dev/null 2>&1; then' >> "$SHELL_CONFIG"
    printf '%s\n' '    if ! command -v fd >/dev/null 2>&1; then' >> "$SHELL_CONFIG"
    printf '%s\n' "        alias fd='fdfind'" >> "$SHELL_CONFIG"
    printf '%s\n' '    fi' >> "$SHELL_CONFIG"
    printf '%s\n' 'fi' >> "$SHELL_CONFIG"

    chown "${REAL_USER}:${REAL_USER}" "$SHELL_CONFIG"
    chmod 600 "$SHELL_CONFIG"
    UPDATED=$((UPDATED + 1))
}

ensure_shell_loader() {
    local rc_file="$1"
    local loader='source "$HOME/.config/kali-setup/shell.sh"'

    if [[ -L "$rc_file" ]]; then
        warning "Arquivo de shell é symlink; ignorado: ${rc_file}"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if [[ ! -e "$rc_file" ]]; then
        : > "$rc_file"
        chown "${REAL_USER}:${REAL_USER}" "$rc_file"
        chmod 600 "$rc_file"
    fi

    if grep -Fq "$loader" "$rc_file"; then
        EXISTING=$((EXISTING + 1))
    else
        backup_file "$rc_file" "${REAL_HOME}/.local/state/kali-setup/backups" >/dev/null
        printf '\n# KALI SETUP - configuração segura do shell\n' >> "$rc_file"
        printf 'if [[ -f "$HOME/.config/kali-setup/shell.sh" ]]; then\n' >> "$rc_file"
        printf '    %s\n' "$loader" >> "$rc_file"
        printf 'fi\n' >> "$rc_file"
        UPDATED=$((UPDATED + 1))
    fi
}

main() {
    print_banner
    require_root
    require_commands getent chown chmod grep date
    REAL_USER="$(get_real_user)"
    REAL_HOME="$(get_user_home "$REAL_USER")"
    LOG_FILE="$(start_log "$REAL_USER" "$MODULE_NAME")"

    if command_exists bash; then
        success "Bash encontrado."
    fi

    if command_exists zsh; then
        success "Zsh encontrado."
    else
        warning "Zsh não encontrado; .zshrc será ignorado se ausente."
    fi

    write_shell_config
    ensure_shell_loader "${REAL_HOME}/.bashrc"

    if [[ -e "${REAL_HOME}/.zshrc" ]]; then
        ensure_shell_loader "${REAL_HOME}/.zshrc"
    fi

    warning "O shell padrão não foi alterado automaticamente."
    print_summary_line 'Instaladas' '0'
    print_summary_line 'Já existentes' "$EXISTING"
    print_summary_line 'Atualizadas' "$UPDATED"
    print_summary_line 'Ignoradas' "$SKIPPED"
    print_summary_line 'Incompatíveis' '0'
    print_summary_line 'Falhas' "$FAILED"
    print_summary_line 'Log' "$LOG_FILE"
    print_summary_line 'Status' 'OK'
    print_summary_line 'Próximo módulo' "$NEXT_MODULE"
}

main "$@"
