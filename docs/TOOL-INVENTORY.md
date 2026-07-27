# Inventário de ferramentas

Formato dos arquivos `config/*.txt`:

```text
nome|categoria|prioridade|método|pacote-ou-origem|comando-validacao|arquitetura
```

Prioridades:

- CORE: instalado por padrão pelo módulo responsável.
- RECOMMENDED: instalado por padrão, com foco em workstation profissional.
- OPTIONAL: os módulos 10 e 11 instalam automaticamente; módulos interativos, como o 15, pedem confirmação.
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
| cmseek | CMS/fingerprint | apt | CORE | Não | Não | 31 | Identificação de múltiplos CMS |
| wpscan | WordPress | apt | CORE | Opcional | token WPScan | 31 | Scanner especializado em WordPress |
| wpprobe | WordPress | apt | RECOMMENDED | Não | base própria | 31 | Enumeração e correlação de plugins |
| joomscan | Joomla | apt | CORE | Não | Não | 31 | Scanner especializado em Joomla |
| droopescan | Drupal/SilverStripe | apt | RECOMMENDED | Não | Não | 31 | Instala quando disponível no APT |
| cmsmap | WordPress/Joomla/Drupal | apt | OPTIONAL | Não | Não | 31 | Instala quando disponível no APT |
| whatweb | CMS/fingerprint | apt | RECOMMENDED | Não | Não | 16/31 | Fingerprint complementar |
| kiterunner | Descoberta de rotas API | build oficial | CORE | Não | cache próprio | 32 | Compilado do repositório oficial; binário `kr` |
| schemathesis | OpenAPI/GraphQL | pipx | RECOMMENDED | Não | schema da API | 32 | Testes generativos orientados a schema |
| jwt_tool | JWT | venv/git | RECOMMENDED | Não | config própria | 32 | Ambiente Python isolado e launcher local |
| grpcurl | gRPC | go | RECOMMENDED | Não | Opcional | 32 | Cliente CLI para serviços gRPC |
| k6 | Carga/desempenho | repositório oficial | CORE | Não | scripts JavaScript | 33 | Testes de carga, estresse, pico e resistência |
| jmeter | Carga/desempenho | apt | CORE | Não | planos JMX | 33 | Apache JMeter; requer Java |
| locust | Carga distribuída | pipx | CORE | Não | locustfile Python | 33 | Cenários programáveis e execução distribuída |
| wrk | Benchmark HTTP | apt | CORE | Não | scripts Lua opcionais | 33 | Gerador HTTP de alto desempenho |
| vegeta | Taxa constante | go | RECOMMENDED | Não | targets locais | 33 | Controle de taxa e relatórios |
| gatling | Cenários de carga | Docker | RECOMMENDED | Não | projeto Gatling | 33 | Imagem oficial e launcher local |
| slowhttptest | Resiliência HTTP | apt | OPTIONAL | Não | Não | 33 | Potencialmente disruptivo; autorização explícita |

Para visualizar inventário local:

```bash
scripts/show-tool-inventory.sh
```
