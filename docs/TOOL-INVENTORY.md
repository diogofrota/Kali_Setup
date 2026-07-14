# Inventário de ferramentas

Formato dos arquivos `config/*.txt`:

```text
nome|categoria|prioridade|método|pacote-ou-origem|comando-validacao|arquitetura
```

Prioridades:

- CORE: instalado por padrão pelo módulo responsável.
- RECOMMENDED: instalado por padrão, com foco em workstation profissional.
- OPTIONAL: pede confirmação.
- LEGACY: documentado, mas não instalado.
- UNSUPPORTED: recusado até nova validação.

| Nome | Categoria | Método | Prioridade | API | Configuração | Módulo | Observação |
|---|---|---|---|---|---|---|---|
| nmap | Rede/portas | apt | CORE | Não | Não | 14/15 | Pacote Kali |
| masscan | Portas | apt | RECOMMENDED | Não | Não | 14/15 | Usar somente em escopo autorizado |
| subfinder | Subdomínios | go | CORE | Opcional | `provider-config.yaml` | 11/15 | ProjectDiscovery oficial |
| httpx | HTTP probing | go | CORE | Não | Alias `httpx-pd` | 11/15 | ProjectDiscovery oficial; conflito conhecido com outros comandos `httpx` |
| dnsx | DNS | go | CORE | Não | Não | 11/15 | ProjectDiscovery oficial |
| nuclei | Vulnerabilidades | go | RECOMMENDED | Opcional | templates/config própria | 11/17 | Não executar scans automaticamente |
| naabu | Portas | go | RECOMMENDED | Não | Não | 11/15 | Requer libpcap |
| katana | Crawling | go | RECOMMENDED | Não | Opcional | 11/15 | ProjectDiscovery oficial |
| ffuf | Conteúdo/fuzzing | apt | RECOMMENDED | Não | Não | 15/16 | Pacote Kali |
| gobuster | Conteúdo/fuzzing | apt | RECOMMENDED | Não | Não | 15/16 | Pacote Kali |
| feroxbuster | Conteúdo/fuzzing | apt/cargo | RECOMMENDED | Não | Não | 12/15/16 | Preferir apt quando disponível |
| amass | Subdomínios | apt | RECOMMENDED | Opcional | própria | 15 | Pacote Kali quando disponível |
| theHarvester | OSINT | apt | OPTIONAL | Opcional | própria | 15/20 | Usar dentro do escopo |
| shodan | Inteligência | pipx | OPTIONAL | Sim | API key | 15/20 | Requer credencial |
| censys | Inteligência | pipx | OPTIONAL | Sim | API token | 15/20 | Requer credencial |
| aquatone | Screenshots | disabled | LEGACY | Não | Não | 15 | Não instalar sem nova validação |
| crackmapexec | AD | disabled | LEGACY | Não | Não | 19 | Preferir NetExec quando validado |

Para visualizar inventário local:

```bash
scripts/show-tool-inventory.sh
```
