# Referência de aliases

Este arquivo relaciona os aliases configurados pelo KALI SETUP com o comando
executado e a finalidade de cada um.

Fonte da configuração: `modules/08-configure-shell.sh`.

Após a execução do módulo 08, os aliases são gravados em:

```text
~/.config/kali-setup/shell.sh
```

## Lista de aliases

| Alias | Comando executado | Ferramenta | O que faz |
|---|---|---|---|
| `ll` | `ls -lah` | `ls` | Lista todos os arquivos, inclusive ocultos, com detalhes e tamanhos legíveis. |
| `la` | `ls -A` | `ls` | Lista arquivos ocultos, mas omite as entradas `.` e `..`. |
| `lt` | `ls -lahtr` | `ls` | Lista arquivos detalhadamente, ordenados por data, dos mais antigos aos mais recentes. |
| `ports` | `ss -tulpen` | `ss` | Mostra sockets TCP e UDP, portas em escuta, processos e informações de rede. |
| `myip-local` | `ip -br addr` | `ip` | Exibe de forma resumida os endereços IP das interfaces locais. |
| `update-kali-setup` | `install.sh --list` | instalador KALI SETUP | Lista os módulos disponíveis no projeto. O nome histórico do alias não executa uma atualização automaticamente. |
| `check-tools` | `check-all-tools.sh` | verificador KALI SETUP | Verifica a disponibilidade das ferramentas registradas nos inventários do projeto. |
| `httpx` | `$HOME/go/bin/httpx` | HTTPX do ProjectDiscovery | Executa explicitamente a ferramenta de reconhecimento HTTP do ProjectDiscovery, evitando conflito com o cliente HTTP Python de mesmo nome. |
| `httpx-pd` | `$HOME/go/bin/httpx` | HTTPX do ProjectDiscovery | Nome alternativo e explícito para executar o HTTPX do ProjectDiscovery. |
| `fd` | `fdfind` | `fd-find` | Permite usar o nome curto `fd` para a ferramenta instalada como `fdfind` no Debian/Kali. |

## Aliases condicionais

Os aliases `httpx` e `httpx-pd` somente são criados quando o arquivo
`$HOME/go/bin/httpx` existe e é executável.

O alias `fd` somente é criado quando:

1. o comando `fdfind` está disponível; e
2. não existe outro comando real chamado `fd` no `PATH`.

Essas condições evitam substituir comandos válidos já instalados.

## Exemplos rápidos

```bash
ll
ports
myip-local
check-tools
httpx-pd -version
fd README
```

## Como conferir os aliases ativos

Para listar somente os aliases configurados pelo projeto:

```bash
for nome in ll la lt ports myip-local update-kali-setup check-tools httpx httpx-pd fd; do
    alias "$nome" 2>/dev/null
done
```

Para descobrir exatamente o que um nome executa:

```bash
type -a httpx
type -a fd
type -a check-tools
```

Se os aliases ainda não estiverem ativos, abra um terminal novo ou recarregue
a configuração:

```bash
source "$HOME/.config/kali-setup/shell.sh"
```

> Em scripts não interativos, prefira o comando ou caminho completo. Aliases
> são destinados principalmente ao uso interativo no terminal.
