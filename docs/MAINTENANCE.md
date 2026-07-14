# Manutenção

Use módulos específicos para atualizar o sistema e ferramentas. Não misture atualização de sistema, Go, Python, Rust e Git em uma rotina sem confirmação.

Rotinas úteis:

```bash
./modules/05-update-system.sh
scripts/update-go-tools.sh
scripts/update-python-tools.sh
scripts/update-git-tools.sh
scripts/check-all-tools.sh
```

Logs dos módulos devem ficar em:

```text
~/.local/state/kali-setup/logs/
```

Logs não devem conter tokens, senhas, API keys ou conteúdo de arquivos secretos.
