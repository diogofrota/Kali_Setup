# Uso das ferramentas do KALI SETUP

Este documento explica, em ordem de uso, as ferramentas previstas nos inventários do KALI SETUP.

Ele não substitui a documentação oficial de cada projeto. A proposta aqui é ser um guia prático para o operador entender:

- para que cada ferramenta serve;
- em qual momento ela entra no fluxo;
- qual comando inicial pode ser usado;
- qual tipo de saída esperar.

As saídas mostradas são exemplos didáticos e resumidos. Elas não foram copiadas de uma execução real neste repositório. Troque domínios, IPs, arquivos e wordlists pelos valores do seu laboratório ou escopo autorizado.

> Nunca execute reconhecimento, fuzzing, enumeração, varredura ou validação de vulnerabilidades contra sistemas sem autorização explícita.

## Convenções usadas nos exemplos

Placeholders:

- `example.com`: domínio de exemplo.
- `192.0.2.10`: IP reservado para documentação.
- `127.0.0.1`: máquina local ou laboratório.
- `wordlist.txt`: wordlist autorizada.
- `subdomains.txt`: lista local de subdomínios.
- `urls.txt`: lista local de URLs.
- `resolvers.txt`: lista local de resolvedores DNS.
- `~/Engagements/cliente/`: pasta de trabalho fora do repositório.

Prioridades usadas pelos inventários:

- `CORE`: ferramenta essencial instalada pelo módulo responsável.
- `RECOMMENDED`: ferramenta recomendada para uma workstation profissional.
- `OPTIONAL`: ferramenta útil, mas deve pedir confirmação.
- `LEGACY`: documentada, mas não instalada.
- `UNSUPPORTED`: recusada até nova validação.

Métodos de instalação:

- `apt`: pacote do Kali/Debian.
- `go`: instalação via `go install`.
- `pipx`: instalação Python isolada por usuário.
- `git`: exige revisão manual.
- `disabled`: não instalar automaticamente.

## Ordem geral de uso em um trabalho autorizado

Este é um fluxo típico. Nem todo engagement usa todas as fases.

| Ordem | Fase | Objetivo | Ferramentas comuns |
|---:|---|---|---|
| 0 | Preparação local | Validar ambiente, pacotes, diretórios e chaves | `bash`, `git`, `tmux`, `jq`, `pipx`, `go`, `docker` |
| 1 | Escopo | Guardar regras, ativos permitidos e limites | `tree`, `less`, `vim`, `nano`, `rsync` |
| 2 | Rede local autorizada | Descobrir hosts e serviços internos | `ip`, `fping`, `arp-scan`, `nmap`, `tcpdump` |
| 3 | DNS e subdomínios | Encontrar nomes, resolver registros e deduplicar | `subfinder`, `assetfinder`, `dnsx`, `shuffledns`, `anew` |
| 4 | HTTP probing | Identificar hosts web vivos e metadados | `httpx`, `httprobe`, `wafw00f` |
| 5 | Crawling e URLs | Coletar caminhos e parâmetros | `katana`, `hakrawler`, `gospider`, `gau`, `waybackurls`, `waymore`, `unfurl`, `qsreplace`, `uro` |
| 6 | Conteúdo web | Descobrir diretórios e arquivos | `ffuf`, `gobuster`, `feroxbuster`, `dirsearch` |
| 7 | TLS e vulnerabilidades | Validar exposição e configurações | `sslscan`, `testssl.sh`, `nuclei`, `cvemap` |
| 8 | Protocolos internos | SMB, LDAP, SNMP, bancos e serviços de rede | `enum4linux-ng`, `smbclient`, `rpcclient`, `ldapsearch`, `snmpwalk` |
| 9 | OSINT/API | Enriquecer descoberta com fontes externas | `theHarvester`, `shodan`, `censys`, `uncover`, `chaos` |
| 10 | Cloud/código | Revisar cloud e IaC autorizado | `scout`, `roadrecon`, `checkov`, `semgrep`, `detect-secrets` |
| 11 | Evidência | Organizar provas e relatórios | `file`, `zip`, `tar`, `rsync`, `gowitness` |
| 12 | Manutenção | Atualizar e validar ferramentas | `check-tool.sh`, `check-all-tools.sh`, `update-go-tools.sh`, `update-python-tools.sh` |

## Atenção a conflitos de nomes no terminal

Algumas ferramentas podem ter nome igual ou parecido com outros programas do sistema. Isso é importante porque o shell executa o primeiro binário encontrado no `PATH`, e um comando aparentemente correto pode chamar outra ferramenta.

O módulo `08-configure-shell.sh` cria aliases para os casos conhecidos.

| Nome | Situação | Como o KALI SETUP trata | Como conferir |
|---|---|---|---|
| `httpx` | Pode existir como cliente HTTP Python ou como ferramenta ProjectDiscovery. Para recon, o projeto espera o `httpx` do ProjectDiscovery instalado em `~/go/bin/httpx`. | Cria `alias httpx="$HOME/go/bin/httpx"` e `alias httpx-pd="$HOME/go/bin/httpx"` quando esse binário existe. | `type -a httpx` |
| `fd` / `fdfind` | No Debian/Kali, o pacote `fd-find` costuma instalar o comando como `fdfind`, não como `fd`. | Cria `alias fd='fdfind'` somente quando `fdfind` existe e nenhum `fd` real está no `PATH`. | `type -a fd fdfind` |
| `docker compose` / `docker-compose` | Existem duas formas comuns de chamar Compose: plugin moderno e binário legado. | O módulo Docker tenta validar `docker compose version` e usa `docker-compose version` como fallback. | `docker compose version` e `docker-compose version` |

Exemplo para conferir o caso do `httpx`:

```bash
type -a httpx
httpx-pd -version
```

Saída ilustrativa:

```text
httpx is aliased to `/home/diogo/go/bin/httpx'
/home/diogo/go/bin/httpx
/usr/bin/httpx
```

Se o alias ainda não apareceu, abra um novo terminal ou carregue novamente a configuração:

```bash
source "$HOME/.config/kali-setup/shell.sh"
```

Em scripts não interativos, não dependa de alias. Use o caminho completo quando houver risco de conflito:

```bash
"$HOME/go/bin/httpx" -u https://example.com -status-code
```

## Fase 0 — Preparação local e ferramentas base

Estas ferramentas sustentam o ambiente. Muitas não são “ferramentas de ataque”; são ferramentas de administração, automação, edição, compilação e diagnóstico.

| Ferramenta | Para que serve | Comando inicial | Saída esperada |
|---|---|---|---|
| `curl` | Fazer requisições HTTP/HTTPS, baixar arquivos e testar APIs. | `curl -I https://example.com` | `HTTP/2 200` |
| `wget` | Baixar arquivos por HTTP/HTTPS/FTP. | `wget --spider https://example.com` | `Remote file exists.` |
| `git` | Versionamento e consulta de repositórios. | `git --version` | `git version 2.x.x` |
| `jq` | Ler e filtrar JSON em scripts. | `jq '.name' exemplo.json` | `"kali-setup"` |
| `yq` | Ler e filtrar YAML. | `yq '.shodan' provider-config.yaml` | `[]` |
| `unzip` | Extrair arquivos `.zip`. | `unzip -l arquivo.zip` | `Archive: arquivo.zip` |
| `zip` | Criar arquivos `.zip`. | `zip -r evidencias.zip evidence/` | `adding: evidence/...` |
| `p7zip-full` / `7z` | Abrir e criar arquivos 7z, zip e outros formatos. | `7z l arquivo.7z` | `Listing archive: arquivo.7z` |
| `tar` | Empacotar diretórios e preservar estrutura. | `tar -tf evidencias.tar` | `evidence/print-01.png` |
| `gzip` | Comprimir arquivos individuais. | `gzip --version` | `gzip 1.x` |
| `bzip2` | Comprimir arquivos com algoritmo bzip2. | `bzip2 --version` | `bzip2, a block-sorting file compressor` |
| `xz-utils` / `xz` | Comprimir arquivos com XZ. | `xz --version` | `xz (XZ Utils) 5.x` |
| `file` | Identificar tipo real de arquivo. | `file payload.bin` | `payload.bin: ELF 64-bit...` |
| `tree` | Visualizar estrutura de diretórios. | `tree -L 2 ~/Engagements/cliente` | `scope/`, `recon/`, `reports/` |
| `rsync` | Copiar evidências preservando estrutura. | `rsync -av --dry-run evidence/ backup/evidence/` | `sending incremental file list` |
| `ripgrep` / `rg` | Buscar texto rapidamente em muitos arquivos. | `rg 'password' ~/Engagements/cliente/notes` | `notes/app.md:password policy...` |
| `fd-find` / `fdfind` | Encontrar arquivos por nome de forma rápida. | `fdfind '\.json$' ~/Engagements/cliente` | `recon/httpx.json` |
| `fzf` | Seleção interativa no terminal. | `fzf --version` | `0.x` |
| `tmux` | Manter sessões persistentes no terminal. | `tmux new -s recon` | Abre uma sessão chamada `recon`. |
| `screen` | Sessões persistentes alternativas ao tmux. | `screen --version` | `Screen version 4.x` |
| `nano` | Editor simples no terminal. | `nano notes.md` | Abre o arquivo no editor. |
| `vim` | Editor avançado no terminal. | `vim notes.md` | Abre o arquivo no editor. |
| `less` | Ler arquivos longos sem carregar tudo no terminal. | `less report.txt` | Visualizador paginado. |
| `man-db` / `man` | Ler manuais locais. | `man nmap` | `NMAP(1)` |
| `ca-certificates` | Certificados raiz para HTTPS confiável. | `update-ca-certificates --help` | `Usage: update-ca-certificates` |
| `gnupg` / `gpg` | Validar assinaturas e chaves. | `gpg --version` | `gpg (GnuPG) 2.x` |
| `lsb-release` | Identificar distribuição. | `lsb_release -a` | `Distributor ID: Kali` |
| `software-properties-common` | Gerenciar repositórios APT extras quando necessário. | `add-apt-repository --help` | `usage: add-apt-repository` |
| `build-essential` | Metapacote de compilação. | `dpkg -s build-essential` | `Status: install ok installed` |
| `pkg-config` | Descobrir flags de bibliotecas. | `pkg-config --version` | `1.x` |
| `make` | Executar build via Makefile. | `make --version` | `GNU Make 4.x` |
| `cmake` | Gerar builds de projetos C/C++. | `cmake --version` | `cmake version 3.x` |
| `gcc` | Compilador C. | `gcc --version` | `gcc (Debian...)` |
| `g++` | Compilador C++. | `g++ --version` | `g++ (Debian...)` |
| `libc6-dev` | Headers da libc para compilação. | `ldd --version` | `ldd (Debian GLIBC...)` |
| `libssl-dev` | Headers OpenSSL para compilar ferramentas TLS/crypto. | `pkg-config --exists openssl` | Código de saída `0` quando existe. |
| `libffi-dev` | Headers FFI usados por pacotes Python. | `pkg-config --exists libffi` | Código de saída `0` quando existe. |
| `libpcap-dev` | Headers de captura de pacotes usados por scanners. | `pcap-config --version` | `1.x` |
| `python3` | Runtime Python. | `python3 --version` | `Python 3.x.x` |
| `python3-venv` | Criar ambientes virtuais Python. | `python3 -m venv --help` | `usage: venv` |
| `python3-dev` | Headers Python para compilar dependências. | `python3-config --includes` | `-I/usr/include/python3.x` |
| `pipx` | Instalar ferramentas Python isoladas. | `pipx --version` | `1.x` |
| `shellcheck` | Análise estática de Bash. | `shellcheck install.sh` | Sem saída quando não há avisos. |
| `openssh-client` / `ssh` | Acessar hosts remotos autorizados. | `ssh -V` | `OpenSSH_9.x` |
| `openssh-server` / `sshd` | Servidor SSH local, opcional. | `sshd -V` | `OpenSSH_9.x` |
| `net-tools` / `ifconfig` | Ferramentas legadas de rede. | `ifconfig --version` | `net-tools 2.x` |
| `iproute2` / `ip` | Interface moderna para IP, rotas e links. | `ip -br addr` | `eth0 UP 192.0.2.20/24` |
| `whois` | Consultar dados WHOIS. | `whois example.com` | `Domain Name: EXAMPLE.COM` |
| `traceroute` | Ver caminho até um host. | `traceroute example.com` | `1  gateway ...` |
| `mtr-tiny` / `mtr` | Combina ping e traceroute. | `mtr --version` | `mtr 0.x` |
| `rlwrap` | Melhorar shells interativos simples. | `rlwrap --version` | `rlwrap 0.x` |

## Fase 1 — Escopo, organização e evidência

Antes de rodar ferramentas de segurança, organize o escopo.

Comando sugerido para visualizar a estrutura de um engagement:

```bash
tree -L 2 ~/Engagements/cliente
```

Saída ilustrativa:

```text
cliente/
├── scope
├── recon
├── scans
├── evidence
├── screenshots
├── notes
└── reports
```

Ferramentas úteis nesta fase:

| Ferramenta | Uso recomendado | Comando | Saída esperada |
|---|---|---|---|
| `nano` | Editar notas rápidas. | `nano notes/escopo.md` | Editor aberto. |
| `vim` | Editar notas e relatórios técnicos. | `vim notes/metodologia.md` | Editor aberto. |
| `less` | Revisar regras de escopo. | `less scope/regras.md` | Texto paginado. |
| `rsync` | Criar cópia controlada de evidências. | `rsync -av --dry-run evidence/ archive/evidence/` | `sending incremental file list` |
| `zip` | Compactar evidências finais. | `zip -r reports/evidencias.zip evidence/` | `adding: evidence/...` |
| `tar` | Empacotar artefatos mantendo permissões. | `tar -cf archive/evidencias.tar evidence/` | Sem saída quando sucesso. |
| `file` | Conferir tipo de evidência. | `file screenshots/login.png` | `PNG image data` |

## Fase 2 — Rede local autorizada

Use apenas em rede própria, laboratório ou escopo autorizado.

| Ferramenta | Para que serve | Comando seguro | Saída ilustrativa |
|---|---|---|---|
| `ip` | Ver interfaces e IP local. | `ip -br addr` | `eth0 UP 192.0.2.20/24` |
| `fping` | Testar múltiplos hosts. | `fping -a -g 192.0.2.1 192.0.2.5` | `192.0.2.3` |
| `arp-scan` | Descobrir hosts na LAN por ARP. | `sudo arp-scan --localnet` | `192.0.2.10  00:11:22:33:44:55  Example Inc.` |
| `netdiscover` | Descoberta passiva/ativa em rede local. | `sudo netdiscover -r 192.0.2.0/24` | `192.0.2.10  00:11:22:33:44:55` |
| `nmap` | Enumerar portas e serviços. | `nmap -sV -Pn 192.0.2.10` | `80/tcp open http nginx` |
| `naabu` | Descoberta rápida de portas com foco em recon. | `naabu -host 192.0.2.10 -p 80,443 -rate 50` | `192.0.2.10:443` |
| `masscan` | Varredura rápida com taxa controlada. | `sudo masscan 192.0.2.0/24 -p80,443 --rate 100` | `Discovered open port 443/tcp on 192.0.2.10` |
| `rustscan` | Scanner rápido de portas, opcional. | `rustscan -a 192.0.2.10 --ulimit 5000` | `Open 192.0.2.10:80` |
| `hping3` | Testes TCP/IP controlados em laboratório. | `sudo hping3 -S -c 3 -p 80 127.0.0.1` | `len=46 ip=127.0.0.1 flags=SA` |
| `tcpdump` | Capturar tráfego no terminal. | `sudo tcpdump -i any host 192.0.2.10 -c 5` | `IP 192.0.2.20.54321 > 192.0.2.10.80` |
| `wireshark` | Analisar pacotes em interface gráfica. | `wireshark` | Interface gráfica aberta. |
| `tshark` | Analisar pacotes no terminal. | `tshark -i any -c 5` | `1 0.000000 192.0.2.20 → 192.0.2.10 TCP` |
| `termshark` | Interface TUI para pacotes. | `termshark -i any` | Interface interativa aberta. |
| `socat` | Criar conexões e relays em laboratório. | `socat -V` | `socat by Gerhard Rieger...` |
| `netcat-openbsd` / `nc` | Testar portas e conexões simples. | `nc -vz 192.0.2.10 80` | `succeeded` |
| `proxychains4` | Encaminhar tráfego por proxy configurado. | `proxychains4 curl https://example.com` | `ProxyChains-3.1 ... HTTP/2 200` |
| `ettercap-text-only` | Laboratório de MITM autorizado. | `ettercap -v` | `ettercap NG-0.x` |

## Fase 3 — DNS e subdomínios

Use esta fase para transformar escopo em nomes resolvíveis e listas deduplicadas.

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `dnsutils` / `dig` | Consultar DNS manualmente. | `dig example.com A +short` | `93.184.216.34` |
| `dnsrecon` | Enumeração DNS autorizada. | `dnsrecon -d example.com` | `A example.com 93.184.216.34` |
| `dnsenum` | Enumeração DNS alternativa. | `dnsenum example.com` | `Host's addresses: 93.184.216.34` |
| `subfinder` | Descoberta passiva de subdomínios. | `subfinder -d example.com -silent` | `www.example.com` |
| `assetfinder` | Descoberta complementar de subdomínios. | `assetfinder --subs-only example.com` | `api.example.com` |
| `chaos-client` / `chaos` | Consulta Chaos ProjectDiscovery, requer API. | `chaos -d example.com -silent` | `dev.example.com` |
| `shuffledns` | Resolver/bruteforçar DNS com lista e resolvers. | `shuffledns -d example.com -list subdomains.txt -r resolvers.txt` | `vpn.example.com` |
| `dnsx` | Resolver e validar registros DNS em lote. | `dnsx -d example.com -a -resp-only` | `93.184.216.34` |
| `puredns` | Resolver listas grandes com validação. | `puredns resolve subdomains.txt -r resolvers.txt` | `www.example.com` |
| `massdns` | Resolução DNS em alta escala. | `massdns -r resolvers.txt -t A subdomains.txt` | `www.example.com. A 93.184.216.34` |
| `anew` | Adicionar somente linhas novas a um arquivo. | `anew subdomains.txt` | Imprime apenas itens ainda não vistos. |

Exemplo de uso de `anew` com entrada:

```bash
printf '%s\n' 'www.example.com' | anew subdomains.txt
```

Saída ilustrativa:

```text
www.example.com
```

## Fase 4 — HTTP probing e tecnologias

Depois de ter domínios/subdomínios, descubra quais respondem HTTP/HTTPS e quais tecnologias aparecem.

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `httpx` | Verificar hosts HTTP vivos e metadados. | `httpx -u https://example.com -status-code -title -tech-detect` | `https://example.com [200] [Example Domain] [nginx]` |
| `httprobe` | Filtrar hosts que respondem HTTP/HTTPS. | `httprobe -prefer-https` | `https://www.example.com` |
| `wafw00f` | Detectar WAF. | `wafw00f https://example.com` | `No WAF detected by the generic detection` |
| `mitmproxy` | Proxy de interceptação para laboratório e testes autorizados. | `mitmproxy --version` | `Mitmproxy: x.x.x` |
| `whatweb` | Ferramenta planejada para fingerprint web. | `whatweb https://example.com` | `HTTPServer[nginx], Title[Example Domain]` |
| `gowitness` | Capturar screenshots de aplicações web. | `gowitness scan single --url https://example.com` | `Screenshot saved: screenshots/example.com.png` |

Observação: `whatweb` aparece no roadmap do módulo Web, mas ainda não está nos inventários atuais.

## Fase 5 — Crawling, URLs e parâmetros

Use para coletar caminhos, endpoints, parâmetros e URLs históricas. Revise escopo antes de alimentar scanners.

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `katana` | Crawler web moderno. | `katana -u https://example.com -silent` | `https://example.com/login` |
| `hakrawler` | Crawler simples para links. | `hakrawler -url https://example.com -depth 1` | `https://example.com/assets/app.js` |
| `gospider` | Crawler web alternativo. | `gospider -s https://example.com -d 1` | `[url] - https://example.com/contact` |
| `gau` | Coletar URLs de fontes históricas. | `gau example.com` | `https://example.com/index.html` |
| `waybackurls` | Coletar URLs do Wayback Machine. | `waybackurls example.com` | `https://example.com/old-login` |
| `waymore` | Coletar URLs e respostas históricas. | `waymore -i example.com -mode U` | `https://example.com/api/v1/users` |
| `unfurl` | Extrair partes de URLs. | `unfurl domains < urls.txt` | `example.com` |
| `qsreplace` | Trocar valores de query string. | `qsreplace FUZZ < urls.txt` | `https://example.com/search?q=FUZZ` |
| `uro` | Normalizar e reduzir URLs duplicadas. | `uro -i urls.txt -o urls-limpas.txt` | `urls-limpas.txt criado` |
| `arjun` | Descobrir parâmetros HTTP. | `arjun -u https://example.com/search -m GET` | `Heuristic found: q, page` |

## Fase 6 — Descoberta de conteúdo web

Use somente com autorização e controle de taxa.

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `ffuf` | Fuzzing de diretórios, arquivos e parâmetros. | `ffuf -u https://example.com/FUZZ -w wordlist.txt -mc 200,301,302 -rate 50` | `admin [Status: 301, Size: 0]` |
| `gobuster` | Descoberta de diretórios, DNS e vhosts. | `gobuster dir -u https://example.com -w wordlist.txt -t 10` | `/admin (Status: 301)` |
| `feroxbuster` | Descoberta recursiva de conteúdo web. | `feroxbuster -u https://example.com -w wordlist.txt -t 5` | `200 GET /login` |
| `dirsearch` | Descoberta de diretórios e arquivos. | `dirsearch -u https://example.com -w wordlist.txt -x 404` | `[200] /admin/` |
| `sqlmap` | Validação autorizada de SQL injection em laboratório. | `sqlmap -u 'http://127.0.0.1/vulnerable.php?id=1' --batch --risk=1 --level=1` | `parameter 'id' appears to be dynamic` |

Use `sqlmap` apenas em laboratório ou escopo formalmente autorizado. Não use contra sistemas públicos sem permissão.

## Fase 7 — TLS, exposição e vulnerabilidades

Estas ferramentas ajudam a validar configurações, CVEs e exposições. Elas não devem ser executadas “no automático” contra alvos fora de escopo.

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `sslscan` | Verificar TLS/SSL. | `sslscan example.com` | `TLSv1.2 enabled`, `TLSv1.3 enabled` |
| `testssl.sh` | Auditoria TLS mais detalhada. | `testssl.sh --fast https://example.com` | `Overall Grade: A` |
| `nuclei` | Rodar templates de validação. | `nuclei -u https://example.com -tags tech -severity info` | `[tech-detect:nginx] [info] https://example.com` |
| `cvemap` | Consultar CVEs. | `cvemap -id CVE-2021-44228` | `CVE-2021-44228 critical log4j` |
| `interactsh-client` | Receber interações OAST controladas. | `interactsh-client -v` | `interactsh-client version x.x.x` |

Para `nuclei`, comece por templates informativos e de baixa severidade em ambiente autorizado. Evite rodar conjuntos agressivos sem entender impacto.

## Fase 8 — Protocolos internos, SMB, LDAP, SNMP e bancos

Use apenas em redes internas autorizadas ou laboratório.

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `enum4linux-ng` | Enumerar SMB/Windows. | `enum4linux-ng -A 192.0.2.10` | `Target Information`, `SMB Dialect` |
| `smbclient` | Listar ou acessar compartilhamentos SMB. | `smbclient -L //192.0.2.10 -N` | `Sharename Type Comment` |
| `samba-common-bin` / `rpcclient` | Consultas RPC em hosts Windows/Samba. | `rpcclient -U '' -N 192.0.2.10 -c srvinfo` | `platform_id : 500` |
| `impacket` | Ferramentas para protocolos Microsoft. | `impacket-smbserver -h` | `usage: smbserver.py` |
| `ldap-utils` / `ldapsearch` | Consultas LDAP. | `ldapsearch -x -H ldap://192.0.2.10 -s base` | `namingContexts: DC=example,DC=local` |
| `snmp` / `snmpwalk` | Consultas SNMP. | `snmpwalk -v2c -c public 192.0.2.10 1.3.6.1.2.1.1` | `SNMPv2-MIB::sysDescr.0 = STRING: ...` |
| `onesixtyone` | Testar comunidades SNMP em escopo autorizado. | `onesixtyone -c comunidades.txt 192.0.2.10` | `192.0.2.10 [public] Linux...` |
| `ike-scan` | Enumerar IKE/IPsec. | `sudo ike-scan 192.0.2.10` | `Handshake returned HDR=(CKY-R=...)` |
| `redis-tools` / `redis-cli` | Cliente Redis. | `redis-cli -h 127.0.0.1 ping` | `PONG` |
| `postgresql-client` / `psql` | Cliente PostgreSQL. | `psql --version` | `psql (PostgreSQL) 16.x` |
| `default-mysql-client` / `mysql` | Cliente MySQL/MariaDB. | `mysql --version` | `mysql Ver 15.x Distrib MariaDB` |

## Fase 9 — OSINT, inteligência e APIs

Algumas ferramentas precisam de chaves configuradas pelo módulo `04-configure-api-keys.sh`.

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `theHarvester` | Coletar e-mails, hosts e fontes OSINT. | `theHarvester -d example.com -b bing` | `Hosts found: www.example.com` |
| `shodan` | Consultar ativos expostos via Shodan. | `shodan host 192.0.2.10` | `Ports: 80, 443` |
| `censys` | Consultar Censys Search. | `censys search 'services.service_name: HTTP'` | `192.0.2.10` |
| `uncover` | Consultar fontes de inteligência suportadas. | `uncover -q 'ssl:"example.com"' -silent` | `192.0.2.10:443` |
| `chaos` | Obter subdomínios do Chaos ProjectDiscovery. | `chaos -d example.com -silent` | `api.example.com` |
| `notify` | Enviar notificações de automações configuradas. | `notify -version` | `notify version x.x.x` |

Fluxo de chaves:

```bash
sudo ./modules/04-configure-api-keys.sh
~/.local/bin/edit-api-keys
~/.local/bin/check-api-keys
source ~/.local/bin/export-api-keys
```

## Fase 10 — Cloud, código e revisão defensiva

Use somente em contas, repositórios e ambientes autorizados.

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `scoutsuite` / `scout` | Auditoria cloud autorizada. | `scout --help` | `usage: scout [provider]` |
| `roadrecon` | Reconhecimento Azure/Entra ID autorizado. | `roadrecon --help` | `usage: roadrecon` |
| `semgrep` | Análise estática de código. | `semgrep --config auto .` | `Ran 120 rules on 30 files` |
| `checkov` | Análise de IaC e cloud config. | `checkov -d .` | `Passed checks: 42, Failed checks: 3` |
| `detect-secrets` | Detectar secrets antes de commit. | `detect-secrets scan` | `"results": { ... }` |

Boas práticas:

- rode `detect-secrets scan` antes de commitar;
- rode `checkov` em Terraform, Kubernetes, CloudFormation e similares;
- rode `semgrep` em código que está dentro do escopo;
- não salve credenciais cloud no repositório.

## Fase 11 — Containers e laboratórios

Docker é usado para laboratórios locais, serviços de apoio e ambientes isolados.

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `docker.io` / `docker` | Engine Docker no Kali. | `docker version` | `Client: Docker Engine`, `Server: Docker Engine` |
| `docker-compose-plugin` | Compose moderno: `docker compose`. | `docker compose version` | `Docker Compose version v2.x` |
| `docker-compose` | Compose legado ou fallback. | `docker-compose version` | `docker-compose version 1.x` |

Cuidados:

- o grupo `docker` equivale a privilégio de root;
- laboratórios vulneráveis devem escutar em `127.0.0.1` por padrão;
- não exponha DVWA, Juice Shop, WebGoat, crAPI ou similares em rede pública.

## Fase 12 — Screenshots, relatórios e arquivamento

| Ferramenta | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `gowitness` | Capturar evidências visuais de páginas web. | `gowitness scan single --url https://example.com` | `Screenshot saved` |
| `zip` | Entregar pacote simples de evidências. | `zip -r reports/evidence.zip evidence/ screenshots/` | `adding: screenshots/...` |
| `tar` | Arquivar preservando estrutura. | `tar -cf archive/engagement.tar reports/ evidence/` | Sem saída quando sucesso. |
| `gzip` | Comprimir arquivo tar. | `gzip archive/engagement.tar` | Cria `engagement.tar.gz`. |
| `rsync` | Sincronizar evidências para backup local. | `rsync -av evidence/ Backups/evidence/` | `sent 12,345 bytes` |

## Fase 13 — Manutenção e validação das ferramentas

Scripts do próprio KALI SETUP:

| Script | Para que serve | Comando | Saída ilustrativa |
|---|---|---|---|
| `scripts/show-tool-inventory.sh` | Mostrar inventário completo. | `scripts/show-tool-inventory.sh` | `NOME CATEGORIA PRIORIDADE MÉTODO...` |
| `scripts/check-tool.sh` | Verificar uma ferramenta específica. Para ferramentas Go, confere `~/go/bin` antes do `PATH`. | `scripts/check-tool.sh httpx` | `Status: INSTALADA` ou `CONFLITO OU FORA DO PADRÃO` |
| `scripts/check-all-tools.sh` | Verificar todas as ferramentas inventariadas e apontar conflitos de nome. | `scripts/check-all-tools.sh` | `Instaladas: 80`, `Ausentes: 12` |
| `scripts/update-go-tools.sh` | Atualizar ferramentas Go CORE/RECOMMENDED. | `scripts/update-go-tools.sh` | `Atualizando subfinder...` |
| `scripts/update-python-tools.sh` | Atualizar ferramentas Python gerenciadas por pipx. | `scripts/update-python-tools.sh` | `Atualizando semgrep` |
| `scripts/update-git-tools.sh` | Listar ferramentas Git que exigem revisão manual. | `scripts/update-git-tools.sh` | `testssl.sh https://github.com/testssl/testssl.sh` |

## Ferramentas opcionais e duplicadas nos inventários

Algumas aparecem em mais de um inventário porque podem ser instaladas por módulos diferentes ou servem como referência opcional.

| Ferramenta | Situação no projeto | Comando de validação | Saída esperada |
|---|---|---|---|
| `feroxbuster` | Pode aparecer como ferramenta web/recon e também opcional. | `feroxbuster --version` | `feroxbuster x.x.x` |
| `wireshark` | Opcional no módulo de rede e no inventário opcional. | `wireshark --version` | `Wireshark x.x.x` |
| `tshark` | Opcional no módulo de rede e no inventário opcional. | `tshark --version` | `TShark x.x.x` |
| `termshark` | Opcional, compatibilidade a confirmar em algumas arquiteturas. | `termshark --version` | `termshark x.x.x` |
| `scoutsuite` | Python/pipx e opcional cloud. | `scout --help` | `usage: scout` |
| `roadrecon` | Python/pipx e opcional Azure. | `roadrecon --help` | `usage: roadrecon` |

## Ferramentas desabilitadas, legadas ou a confirmar

Estas ferramentas estão documentadas para evitar instalação automática sem análise. Não fazem parte do fluxo normal até nova validação.

| Ferramenta | Status | Motivo | Comando apenas para identificação |
|---|---|---|---|
| `aquatone` | `LEGACY` | Projeto legado; confirmar manutenção antes de usar. | `aquatone -version` |
| `crackmapexec` | `LEGACY` | Preferir NetExec quando validado no projeto. | `crackmapexec --version` |
| `ripgen` | `UNSUPPORTED` | Confirmar manutenção e relevância. | `ripgen --version` |
| `rusthound-ce` | `UNSUPPORTED` | Confirmar origem oficial e compatibilidade. | `rusthound-ce --version` |
| `findomain` | `OPTIONAL` desabilitada | Confirmar suporte oficial para a arquitetura atual. | `findomain --version` |
| `eyewitness` | `OPTIONAL` desabilitada | Confirmar compatibilidade no Kali atual. | `eyewitness --help` |
| `urldedupe` | `OPTIONAL` desabilitada | Confirmar origem oficial e manutenção. | `urldedupe -h` |

## Fluxo exemplo completo de reconhecimento autorizado

Este exemplo usa arquivos locais para organizar a saída. Ajuste nomes conforme o engagement.

### 1. Criar estrutura de trabalho

```bash
mkdir -p ~/Engagements/cliente/recon
```

Saída esperada:

```text
sem saída quando sucesso
```

### 2. Coletar subdomínios

```bash
subfinder -d example.com -silent -o ~/Engagements/cliente/recon/subfinder.txt
```

Saída esperada:

```text
www.example.com
api.example.com
```

### 3. Resolver DNS

```bash
dnsx -l ~/Engagements/cliente/recon/subfinder.txt -a -resp -o ~/Engagements/cliente/recon/resolved.txt
```

Saída esperada:

```text
www.example.com [A] [93.184.216.34]
```

### 4. Identificar HTTP/HTTPS

```bash
httpx -l ~/Engagements/cliente/recon/subfinder.txt -status-code -title -tech-detect -o ~/Engagements/cliente/recon/httpx.txt
```

Saída esperada:

```text
https://www.example.com [200] [Example Domain] [nginx]
```

### 5. Fazer crawling leve

```bash
katana -list ~/Engagements/cliente/recon/httpx.txt -silent -o ~/Engagements/cliente/recon/katana.txt
```

Saída esperada:

```text
https://www.example.com/login
https://www.example.com/assets/app.js
```

### 6. Normalizar URLs

```bash
uro -i ~/Engagements/cliente/recon/katana.txt -o ~/Engagements/cliente/recon/urls-limpas.txt
```

Saída esperada:

```text
arquivo urls-limpas.txt criado
```

### 7. Rodar validações informativas

```bash
nuclei -l ~/Engagements/cliente/recon/httpx.txt -tags tech -severity info -o ~/Engagements/cliente/recon/nuclei-info.txt
```

Saída esperada:

```text
[tech-detect:nginx] [info] https://www.example.com
```

### 8. Capturar screenshots

```bash
gowitness scan file -f ~/Engagements/cliente/recon/httpx.txt --screenshot-path ~/Engagements/cliente/screenshots
```

Saída esperada:

```text
Screenshot saved for https://www.example.com
```

### 9. Revisar possíveis secrets antes de relatório ou commit

```bash
detect-secrets scan ~/Engagements/cliente
```

Saída esperada:

```json
{
  "results": {}
}
```

## Boas práticas finais

- Comece sempre pelo escopo.
- Salve saídas em arquivos dentro do engagement.
- Use taxa baixa em ferramentas ativas.
- Separe descoberta passiva de varredura ativa.
- Não rode ferramentas destrutivas sem entender impacto.
- Nunca publique chaves, tokens ou dados de cliente.
- Prefira evidências reproduzíveis: comando usado, data, alvo autorizado e saída.
- Valide ferramentas com `scripts/check-tool.sh` antes de depender delas.
- Leia a documentação oficial antes de usar opções avançadas.
