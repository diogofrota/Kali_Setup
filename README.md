# KALI SETUP

KALI SETUP é uma suíte modular de scripts Bash para preparar um Kali Linux recém-instalado para uso profissional em Pentest, Red Team, Bug Bounty, OSINT, reconhecimento, laboratórios e estudos de segurança.

A ideia do projeto é tratar a preparação da máquina como software profissional: cada módulo tem uma responsabilidade clara, os arquivos sensíveis são validados antes de qualquer alteração, backups são criados quando necessário, logs são mantidos fora do Git e chaves de API nunca são impressas no terminal.

> Use este projeto somente em ambientes próprios, laboratórios ou escopos formalmente autorizados. Ferramentas de reconhecimento, enumeração, fuzzing e exploração podem causar impacto real em sistemas de terceiros.

## Status atual

O repositório já possui a estrutura principal do KALI SETUP:

- Módulos reais de `01` a `15`, responsáveis por usuário, hostname, API keys, atualização do sistema, pacotes base, diretórios, shell, Git, Python, Go, Rust, Docker, ferramentas de rede e ferramentas de reconhecimento.
- Módulos planejados de `16` a `30`, já criados como placeholders documentados para Web, vulnerabilidades, senhas, Active Directory, OSINT, Cloud, Mobile, Wireless, Forense, Relatórios, Wordlists, Laboratórios, PATH, Validação e Atualização.
- Inventários parseáveis em `config/*.txt`, usados pelos módulos e scripts auxiliares para decidir o que instalar, validar ou ignorar.
- Documentação complementar em `docs/`.
- Scripts auxiliares em `scripts/` para validação, edição de chaves, exportação segura de variáveis e manutenção de ferramentas.

Importante: o projeto não executa scans automaticamente contra alvos. Ele prepara o ambiente local. A execução das ferramentas contra qualquer alvo continua sendo responsabilidade do operador e deve respeitar autorização explícita.

## Estrutura do repositório

```text
kali-setup/
├── README.md
├── .gitignore
├── install.sh
├── config/
│   ├── api-keys.env.example
│   ├── packages-base.txt
│   ├── packages-network.txt
│   ├── subfinder-provider-config.yaml.example
│   ├── tools-disabled.txt
│   ├── tools-git.txt
│   ├── tools-go.txt
│   ├── tools-optional.txt
│   ├── tools-python.txt
│   └── engagement-template/
│       ├── README.md
│       ├── archive/.gitkeep
│       ├── evidence/.gitkeep
│       ├── notes/.gitkeep
│       ├── payloads/.gitkeep
│       ├── recon/.gitkeep
│       ├── reports/.gitkeep
│       ├── requests/.gitkeep
│       ├── responses/.gitkeep
│       ├── scans/.gitkeep
│       ├── scope/.gitkeep
│       └── screenshots/.gitkeep
├── docs/
│   ├── API-KEYS.md
│   ├── AUTHORIZED-USE.md
│   ├── INSTALLATION.md
│   ├── MAINTENANCE.md
│   ├── TOOL-INVENTORY.md
│   ├── TROUBLESHOOTING.md
│   └── USO-DAS-FERRAMENTAS.md
├── lib/
│   └── common.sh
├── logs/
│   └── .gitkeep
├── modules/
│   ├── 01-create-user.sh
│   ├── 02-hostname.sh
│   ├── 03-remove-user.sh
│   ├── 04-configure-api-keys.sh
│   ├── 05-update-system.sh
│   ├── 06-base-packages.sh
│   ├── 07-create-directories.sh
│   ├── 08-configure-shell.sh
│   ├── 09-configure-git.sh
│   ├── 10-install-python.sh
│   ├── 11-install-go.sh
│   ├── 12-install-rust.sh
│   ├── 13-install-docker.sh
│   ├── 14-install-network-tools.sh
│   ├── 15-install-recon-tools.sh
│   ├── 16-install-web-tools.sh
│   ├── 17-install-vulnerability-tools.sh
│   ├── 18-install-password-tools.sh
│   ├── 19-install-active-directory-tools.sh
│   ├── 20-install-osint-tools.sh
│   ├── 21-install-cloud-tools.sh
│   ├── 22-install-mobile-tools.sh
│   ├── 23-install-wireless-tools.sh
│   ├── 24-install-forensics-tools.sh
│   ├── 25-install-reporting-tools.sh
│   ├── 26-install-wordlists.sh
│   ├── 27-install-lab-environments.sh
│   ├── 28-configure-tool-paths.sh
│   ├── 29-validate-installation.sh
│   └── 30-update-security-tools.sh
└── scripts/
    ├── check-all-tools.sh
    ├── check-api-keys.sh
    ├── check-tool.sh
    ├── edit-api-keys.sh
    ├── export-api-keys.sh
    ├── show-tool-inventory.sh
    ├── update-git-tools.sh
    ├── update-go-tools.sh
    └── update-python-tools.sh
```

## Como usar

Entre no diretório do projeto:

```bash
cd ~/kali-setup
```

Liste os módulos disponíveis:

```bash
./install.sh --list
```

Valide a sintaxe Bash dos módulos, scripts e biblioteca comum:

```bash
./install.sh --validate
```

Simule a chamada de um módulo sem executá-lo:

```bash
./install.sh --dry-run --module 15
```

Abra o menu interativo:

```bash
./install.sh
```

Execute um módulo específico pelo orquestrador:

```bash
sudo ./install.sh --module 05
```

Ou execute diretamente o módulo desejado:

```bash
sudo ./modules/05-update-system.sh
```

O único atalho de categoria existente no momento é `recon`:

```bash
sudo ./install.sh --category recon
```

Esse comando chama o módulo `15-install-recon-tools.sh`.

## Fluxo recomendado de primeira instalação

Em uma instalação nova do Kali, um fluxo seguro e previsível seria:

```bash
sudo ./modules/01-create-user.sh
sudo ./modules/02-hostname.sh
sudo ./modules/04-configure-api-keys.sh
sudo ./modules/05-update-system.sh
sudo ./modules/06-base-packages.sh
sudo ./modules/07-create-directories.sh
sudo ./modules/08-configure-shell.sh
sudo ./modules/09-configure-git.sh
sudo ./modules/10-install-python.sh
sudo ./modules/11-install-go.sh
sudo ./modules/12-install-rust.sh
sudo ./modules/13-install-docker.sh
sudo ./modules/14-install-network-tools.sh
sudo ./modules/15-install-recon-tools.sh
```

O módulo `03-remove-user.sh` é intencionalmente separado porque remove o usuário legado `parallels`. Ele é destrutivo e só deve ser executado quando você realmente quiser remover esse usuário:

```bash
sudo ./modules/03-remove-user.sh
```

## Pastas do projeto

### Raiz do projeto

A raiz contém os arquivos principais de entrada: este README, o `.gitignore` e o orquestrador `install.sh`.

É o ponto de partida para quem acabou de clonar o projeto e quer entender como executar, validar ou manter a suíte.

### `config/`

Guarda modelos públicos e inventários de ferramentas.

Nenhum arquivo dentro de `config/` deve conter credenciais reais. Arquivos com `.example` são exemplos seguros para versionamento no Git. Arquivos `.txt` são inventários parseáveis usados pelos módulos para instalar ou validar ferramentas.

### `config/engagement-template/`

Modelo de organização de um engagement autorizado.

Ele não deve conter dados reais de clientes. A ideia é servir como referência para criar uma estrutura fora do repositório, por exemplo em `~/Engagements/<cliente-ou-programa>/`.

Subpastas:

- `scope/`: escopo autorizado, regras de programa, limites de teste e ativos permitidos.
- `recon/`: resultados de reconhecimento passivo e ativo autorizado.
- `scans/`: saídas de scanners e validadores.
- `evidence/`: evidências técnicas, preferencialmente com permissões restritas.
- `screenshots/`: capturas de tela usadas como evidência ou apoio a relatórios.
- `notes/`: anotações operacionais.
- `requests/`: requisições HTTP, exemplos de payloads enviados e material de reprodução.
- `responses/`: respostas HTTP, headers, corpos relevantes e provas técnicas.
- `payloads/`: payloads de laboratório ou de escopo permitido.
- `reports/`: relatórios finais ou rascunhos.
- `archive/`: material fechado, compactado ou preservado.

Os arquivos `.gitkeep` existem apenas para manter essas pastas vazias dentro do Git.

### `docs/`

Documentação complementar. O README explica o projeto inteiro em alto nível; os arquivos em `docs/` aprofundam temas específicos.

### `lib/`

Biblioteca comum dos scripts.

O arquivo `lib/common.sh` centraliza funções reutilizáveis para mensagens, validações, permissões, logs, backups, detecção de Kali e instalação via APT.

### `logs/`

Diretório reservado para logs do projeto dentro do repositório.

Atualmente ele contém apenas `.gitkeep`. Os módulos reais criam logs operacionais no home do usuário, em `~/.local/state/kali-setup/logs/`, para evitar misturar logs locais com arquivos versionados.

### `modules/`

Contém os módulos numerados do KALI SETUP.

A regra do projeto é uma responsabilidade por módulo. Por exemplo: o módulo de hostname não remove usuário, o módulo de Docker não configura API keys, e o módulo de rede não altera Git.

### `scripts/`

Contém utilitários auxiliares que não são módulos de setup completos.

Eles servem para consultar inventário, checar ferramentas, editar chaves, exportar variáveis e atualizar ferramentas instaladas por métodos específicos.

## Arquivos da raiz

### `README.md`

Documento principal do projeto.

Explica a estrutura, o fluxo de uso, o papel de cada pasta, cada arquivo importante, os módulos disponíveis e as ferramentas usadas pelos scripts.

### `.gitignore`

Protege o projeto contra inclusão acidental de credenciais e artefatos locais.

Ele ignora arquivos como:

- `.env`
- `.env.*`
- `api-keys.env`
- `provider-config.yaml`
- diretórios `secrets/` e `credentials/`
- chaves privadas como `.pem`, `.key`, `.p12`, `.pfx`
- cofres locais como `.kdbx`

Ele não ignora os modelos seguros:

- `config/api-keys.env.example`
- `config/subfinder-provider-config.yaml.example`

### `install.sh`

Orquestrador interativo do projeto.

Responsabilidades:

- descobrir a raiz do projeto com segurança;
- localizar a pasta `modules/`;
- listar módulos disponíveis;
- validar se um módulo existe, é arquivo regular, não é link simbólico e está executável;
- executar um módulo por número;
- oferecer modo `--dry-run`;
- validar sintaxe dos scripts com `bash -n`;
- pedir confirmação antes de módulos sensíveis;
- manter o operador no controle, sem executar tudo automaticamente.

Comandos úteis:

```bash
./install.sh --list
./install.sh --validate
./install.sh --dry-run --module 15
sudo ./install.sh --module 05
sudo ./install.sh --category recon
```

Módulos considerados sensíveis pelo orquestrador exigem digitar `EXECUTAR` antes da chamada.

## Biblioteca comum

### `lib/common.sh`

Biblioteca carregada pelos módulos mais novos com `source`.

Principais funções:

- `info`, `success`, `warning`, `error`: saída visual padronizada.
- `die`: imprime erro e retorna falha.
- `kali_setup_handle_error`: handler para `trap ERR`.
- `require_root`: exige execução como root.
- `require_command` e `require_commands`: validam dependências do sistema.
- `get_real_user`: identifica o usuário real, respeitando `SUDO_USER`.
- `get_user_home`: descobre o home real via `getent passwd`.
- `validate_not_symlink`: recusa links simbólicos em caminhos sensíveis.
- `validate_regular_file`: exige arquivo regular.
- `validate_file_owner`: valida proprietário e grupo.
- `validate_file_mode`: valida permissão numérica.
- `ensure_directory`: cria diretório com modo e dono corretos.
- `print_summary_line`: imprime resumo alinhado.
- `detect_architecture`: usa `uname -m`.
- `detect_kali`: valida `/etc/os-release` e recusa sistemas que não sejam Kali.
- `command_exists`: verifica se um binário está no `PATH`.
- `apt_package_exists`: consulta existência de pacote no APT.
- `apt_package_installed`: consulta instalação via `dpkg-query`.
- `install_apt_packages`: instala lista de pacotes por APT com validação.
- `run_as_real_user`: executa comandos como o usuário real usando `sudo -u`.
- `ensure_path_entry`: adiciona entrada de PATH de forma idempotente.
- `backup_file`: cria backup preservando modo, dono e timestamps.
- `confirm_action`: pergunta `[s/N]` antes de ação opcional.
- `start_log`: cria logs privados em `~/.local/state/kali-setup/logs/`.
- `validate_url_domain`: aceita URL somente em domínio esperado.
- `validate_git_repository`: limita repositórios Git a origens permitidas.
- `validate_binary`: valida presença de binário.

Essa biblioteca não executa alterações no sistema quando é carregada. Ela apenas define funções.

## Módulos

### `modules/01-create-user.sh`

Cria e configura o usuário principal do ambiente.

Configuração padrão:

- usuário: `diogo`
- nome completo: `Diogo Frota`
- home: `/home/diogo`
- shell: `/bin/bash`
- grupo administrativo: `sudo`

O que faz:

- confirma execução como root;
- valida nome de usuário;
- verifica se o usuário já existe;
- cria o usuário quando necessário;
- garante home correto;
- define shell padrão;
- adiciona o usuário ao grupo `sudo`;
- valida o resultado final.

Não altera hostname, não remove usuários e não instala ferramentas.

### `modules/02-hostname.sh`

Configura o hostname da máquina.

Objetivo:

- definir o hostname como `kali`;
- ajustar hostname estático e transiente com `hostnamectl`;
- garantir `/etc/hostname` coerente;
- garantir entrada local `127.0.1.1` em `/etc/hosts`;
- criar backup antes de modificar arquivos sensíveis;
- fazer rollback quando uma falha interceptável ocorre.

Arquivos sensíveis envolvidos:

- `/etc/hostname`
- `/etc/hosts`

Backups:

- `/var/backups/kali-setup`

Risco: hostname e resolução local afetam prompt, logs, serviços e ferramentas que dependem do nome da máquina.

### `modules/03-remove-user.sh`

Remove o usuário legado `parallels` com validação rígida.

O que faz:

- confirma execução com `sudo`;
- confirma que `SUDO_USER` é `diogo`;
- verifica se `diogo` existe;
- verifica se `/home/diogo` existe;
- verifica se `diogo` pertence ao grupo `sudo`;
- verifica se `parallels` existe;
- impede remoção de `root`;
- valida que o home de `parallels` é exatamente `/home/parallels`;
- solicita confirmação literal digitando `REMOVER`;
- encerra processos do usuário `parallels`;
- executa remoção do usuário e do home;
- remove grupo residual somente se estiver vazio;
- valida que `diogo` continua funcional.

É um módulo destrutivo. Revise a saída antes de confirmar.

### `modules/04-configure-api-keys.sh`

Prepara armazenamento seguro para chaves de API.

O que faz:

- exige execução via `sudo` a partir do usuário real `diogo`;
- descobre o home real com `getent passwd`;
- cria `~/.config/kali-setup/` com permissão `700`;
- cria `~/.config/kali-setup/api-keys.env` com permissão `600`;
- preserva valores existentes;
- adiciona somente variáveis ausentes;
- instala utilitários em `~/.local/bin`;
- cria configuração real do Subfinder quando seguro;
- valida dono, grupo, permissões e formato final.

Arquivos reais criados fora do Git:

- `~/.config/kali-setup/api-keys.env`
- `~/.config/subfinder/provider-config.yaml`

Esse módulo não valida chaves online e não faz chamadas para APIs externas.

### `modules/05-update-system.sh`

Atualiza o sistema base.

O que faz:

- valida que está no Kali;
- verifica conectividade de forma leve com DNS e preparação de URIs do APT;
- executa `apt update`;
- mostra pacotes atualizáveis;
- pergunta antes de `apt full-upgrade`;
- pergunta antes de `apt autoremove`;
- executa `apt autoclean`;
- roda `dpkg --audit`;
- roda `apt-get check`;
- avisa se `/var/run/reboot-required` existir;
- registra log privado.

Risco: atualização de sistema pode alterar bibliotecas, serviços e kernel. Por isso o upgrade completo exige confirmação.

### `modules/06-base-packages.sh`

Instala pacotes base definidos em `config/packages-base.txt`.

O que faz:

- valida Kali e permissões root;
- lê o inventário linha por linha;
- instala pacotes `CORE` e `RECOMMENDED`;
- pergunta antes de pacotes `OPTIONAL`;
- ignora linhas inválidas;
- não instala metapacotes grandes como `kali-linux-everything`.

Tipos de pacotes cobertos:

- download e HTTP: `curl`, `wget`;
- Git e JSON/YAML: `git`, `jq`, `yq`;
- compactação: `zip`, `unzip`, `tar`, `gzip`, `bzip2`, `xz-utils`, `p7zip-full`;
- terminal e busca: `tmux`, `screen`, `ripgrep`, `fd-find`, `fzf`;
- editores: `nano`, `vim`;
- compilação: `build-essential`, `gcc`, `g++`, `make`, `cmake`, `pkg-config`;
- Python: `python3`, `python3-venv`, `python3-dev`, `pipx`;
- rede básica: `iproute2`, `dnsutils`, `whois`, `tcpdump`, `socat`, `netcat-openbsd`.

### `modules/07-create-directories.sh`

Cria uma estrutura profissional no home do usuário.

Diretórios criados:

- `Labs`
- `Projects`
- `Scripts`
- `Tools`
- `Git`
- `Reports`
- `Clients`
- `Notes`
- `Wordlists`
- `Payloads`
- `Docker`
- `Captures`
- `Evidence`
- `Screenshots`
- `Engagements`
- `Templates`
- `Backups`
- `Temp`
- `Logs`

Diretórios privados recebem permissão mais restritiva:

- `Clients`
- `Evidence`
- `Backups`

O módulo recusa links simbólicos para evitar sobrescrever caminhos inesperados.

### `modules/08-configure-shell.sh`

Configura o shell do usuário sem armazenar secrets.

O que faz:

- cria `~/.config/kali-setup/shell.sh`;
- adiciona `~/.local/bin`, `~/go/bin` e `~/.cargo/bin` ao `PATH`;
- configura histórico mais amplo;
- adiciona aliases úteis;
- adiciona loader em `.bashrc`;
- adiciona loader em `.zshrc` somente se o arquivo existir;
- cria backup antes de alterar arquivo de shell existente;
- não altera automaticamente o shell padrão do usuário.

Aliases criados:

- `ll`: lista arquivos com detalhes.
- `la`: lista arquivos ocultos.
- `lt`: lista por data.
- `ports`: mostra sockets com `ss`.
- `myip-local`: mostra IPs locais.
- `update-kali-setup`: lista módulos.
- `check-tools`: chama validação de ferramentas.
- `httpx`: força o uso de `~/go/bin/httpx` quando o binário do ProjectDiscovery existe.
- `httpx-pd`: alias explícito para o `httpx` do ProjectDiscovery.
- `fd`: aponta para `fdfind` somente quando `fdfind` existe e nenhum `fd` real está no `PATH`.

O caso do `httpx` merece atenção: em alguns ambientes, `httpx` pode chamar outro programa com o mesmo nome, especialmente relacionado ao ecossistema Python. Para recon, o KALI SETUP espera o `httpx` do ProjectDiscovery. Confira com:

```bash
type -a httpx
httpx-pd -version
```

### `modules/09-configure-git.sh`

Configura Git global do usuário.

O que faz:

- pergunta `user.name`;
- pergunta `user.email`;
- configura branch inicial como `main`;
- pergunta se deve configurar `pull.rebase=false`;
- pergunta editor Git;
- pergunta se deve usar `credential.helper cache`;
- evita `credential.helper store` por padrão;
- cria ou atualiza `~/.gitignore_global`;
- adiciona padrões de secrets ao gitignore global;
- configura `core.excludesfile`.

Risco evitado: salvar credenciais em texto puro dentro de repositórios ou em helper persistente sem necessidade.

### `modules/10-install-python.sh`

Instala runtime Python e ferramentas Python.

O que faz:

- instala `python3`, `python3-venv`, `python3-dev` e `pipx`;
- cria `~/.virtualenvs` com permissão restritiva;
- executa `pipx ensurepath`;
- processa `config/tools-python.txt`;
- instala ferramentas via APT quando o método é `apt`;
- instala ferramentas via `pipx` quando o método é `pipx`;
- pergunta antes de ferramentas `OPTIONAL`;
- evita `sudo pip install`;
- evita instalar pacotes Python globalmente no Python do sistema.

Ferramentas Python do inventário:

- `impacket`: scripts úteis para SMB, Kerberos e Active Directory.
- `wafw00f`: identificação de WAF.
- `arjun`: descoberta de parâmetros HTTP.
- `sqlmap`: teste autorizado de SQL injection.
- `dirsearch`: descoberta de conteúdo web.
- `mitmproxy`: proxy de interceptação local.
- `scoutsuite`: auditoria cloud.
- `roadrecon`: reconhecimento Azure/Entra ID autorizado.
- `semgrep`: análise estática de código.
- `checkov`: análise de IaC e cloud security.
- `detect-secrets`: detecção de secrets antes de commit.
- `waymore`: coleta de URLs históricas e fontes OSINT.
- `uro`: normalização e limpeza de URLs.
- `shodan`: CLI da Shodan.
- `censys`: CLI da Censys.
- `theHarvester`: OSINT de domínios, e-mails e hosts.

### `modules/11-install-go.sh`

Instala Go e ferramentas escritas em Go.

O que faz:

- valida Kali;
- cria `~/go/bin`;
- instala `golang-go` via APT se `go` não existir;
- processa `config/tools-go.txt`;
- instala ferramentas `CORE` e `RECOMMENDED` com `go install`;
- pergunta antes de ferramentas `OPTIONAL`;
- define `GOPATH` e `GOBIN` para instalar no home do usuário;
- executa instalação como usuário real, não como root.
- valida ferramentas Go pelo binário esperado em `~/go/bin`, evitando confundir o `httpx` do ProjectDiscovery com outro comando de mesmo nome no sistema.

Ferramentas Go do inventário:

- `subfinder`: enumeração passiva de subdomínios.
- `httpx`: probing HTTP/HTTPS e coleta de metadados.
- `nuclei`: execução de templates de validação de vulnerabilidades em escopos autorizados.
- `naabu`: descoberta de portas.
- `dnsx`: consultas e validações DNS.
- `katana`: crawler web.
- `uncover`: consulta fontes de inteligência.
- `interactsh-client`: OAST para interações controladas.
- `notify`: envio de notificações em fluxos de automação.
- `cvemap`: consulta e organização de CVEs.
- `chaos-client`: cliente do Chaos ProjectDiscovery.
- `shuffledns`: resolução e enumeração DNS com listas.
- `assetfinder`: descoberta de domínios e subdomínios.
- `anew`: deduplicação incremental de resultados.
- `qsreplace`: substituição de query strings em URLs.
- `unfurl`: extração de partes de URLs.

O inventário também lista ferramentas instaladas via APT que fazem parte do ecossistema de recon, como `ffuf`, `gobuster` e `feroxbuster`.

### `modules/12-install-rust.sh`

Instala Rust/Cargo e ferramentas Rust opcionais.

O que faz:

- cria `~/.cargo/bin`;
- instala `cargo` e `rustc` via APT quando disponíveis;
- não executa instaladores remotos como `rustup` automaticamente;
- pergunta antes de instalar ferramentas via `cargo install`;
- mantém `ripgen` e `rusthound-ce` desabilitados até nova validação.

Ferramentas opcionais tratadas:

- `feroxbuster`: discovery/fuzzing de conteúdo web.
- `rustscan`: scanner de portas rápido, para uso autorizado.

### `modules/13-install-docker.sh`

Instala e configura Docker.

O que faz:

- instala `docker.io`;
- evita instalar o pacote errado chamado `docker`;
- tenta instalar `docker-compose-plugin`;
- usa `docker-compose` como fallback quando o plugin não existe;
- pergunta antes de habilitar Docker no boot;
- pergunta antes de iniciar Docker agora;
- alerta que o grupo `docker` concede privilégios equivalentes a root;
- pergunta antes de adicionar o usuário real ao grupo `docker`;
- valida `docker version`;
- valida `docker compose version` ou `docker-compose version`.

Risco importante: membros do grupo `docker` podem escalar privilégios no sistema. Só aceite essa opção se entender o impacto.

### `modules/14-install-network-tools.sh`

Instala ferramentas de rede definidas em `config/packages-network.txt`.

O que faz:

- instala ferramentas `CORE` e `RECOMMENDED`;
- pergunta antes de ferramentas `OPTIONAL`;
- valida disponibilidade no `apt-cache`;
- processa apenas método `apt`;
- pergunta antes de configurar captura Wireshark para usuários não root.

Ferramentas de rede do inventário:

- `nmap`: varredura e enumeração de portas/serviços.
- `masscan`: varredura rápida de portas, exige cuidado com taxa e escopo.
- `arp-scan`: descoberta ARP em rede local.
- `netdiscover`: descoberta em rede local.
- `fping`: ping em massa.
- `hping3`: geração e teste de pacotes TCP/IP.
- `tcpdump`: captura de tráfego.
- `wireshark`: análise gráfica de pacotes.
- `tshark`: análise de pacotes no terminal.
- `termshark`: interface TUI para análise de pacotes.
- `ettercap-text-only`: ferramenta de análise e laboratório MITM, somente em ambiente autorizado.
- `socat`: relay e teste de sockets.
- `netcat-openbsd`: conexões TCP/UDP simples.
- `proxychains4`: encaminhamento de conexões por proxies.
- `dnsutils`: `dig`, `nslookup` e utilitários DNS.
- `dnsrecon`: enumeração DNS.
- `dnsenum`: enumeração DNS.
- `enum4linux-ng`: enumeração SMB/Windows.
- `smbclient`: cliente SMB.
- `samba-common-bin`: inclui utilitários como `rpcclient`.
- `snmp`: ferramentas SNMP como `snmpwalk`.
- `onesixtyone`: enumeração SNMP.
- `ike-scan`: enumeração IKE/IPsec.
- `sslscan`: análise TLS/SSL.
- `ldap-utils`: ferramentas LDAP como `ldapsearch`.
- `redis-tools`: cliente Redis.
- `postgresql-client`: cliente PostgreSQL.
- `default-mysql-client`: cliente MySQL/MariaDB.

### `modules/15-install-recon-tools.sh`

Instala ferramentas de reconhecimento a partir de múltiplos inventários.

Arquivos processados:

- `config/tools-go.txt`
- `config/tools-python.txt`
- `config/tools-git.txt`
- `config/tools-disabled.txt`

Métodos suportados:

- `apt`: instala via APT.
- `go`: instala via `go install`.
- `pipx`: instala via `pipx install`.
- `git`: não instala automaticamente; exige revisão manual.
- `disabled`: documenta, mas não instala.

Prioridades:

- `CORE`: instala por padrão.
- `RECOMMENDED`: instala por padrão.
- `OPTIONAL`: pergunta antes.
- `LEGACY`: não instala.
- `UNSUPPORTED`: não instala.

Categorias cobertas:

- subdomínios;
- DNS;
- HTTP probing;
- portas;
- crawling;
- URLs;
- screenshots;
- inteligência;
- organização de resultados.

### `modules/16-install-web-tools.sh`

Módulo planejado para ferramentas Web.

Escopo documentado:

- Burp Community;
- OWASP ZAP;
- `ffuf`;
- `feroxbuster`;
- `gobuster`;
- `nikto`;
- `sqlmap`;
- `arjun`;
- `wafw00f`;
- `whatweb`;
- `wpscan`;
- navegadores.

No estado atual, apenas imprime objetivo, escopo, dependências e TODOs. Não instala ferramentas.

### `modules/17-install-vulnerability-tools.sh`

Módulo planejado para validadores e scanners de vulnerabilidade.

Escopo documentado:

- `nuclei`;
- templates oficiais;
- `sslscan`;
- `testssl.sh`;
- ferramentas defensivas de revisão.

Não executa scans automaticamente.

### `modules/18-install-password-tools.sh`

Módulo planejado para auditoria de senhas em laboratório ou escopo autorizado.

Escopo documentado:

- `hashcat`;
- `john`;
- wordlists;
- utilitários de identificação de hashes.

Deve validar suporte de GPU/ARM64 e espaço em disco antes de instalar.

### `modules/19-install-active-directory-tools.sh`

Módulo planejado para auditoria Active Directory autorizada.

Escopo documentado:

- `impacket`;
- NetExec;
- BloodHound/BloodHound CE;
- `certipy-ad`;
- `kerbrute`;
- `responder`;
- `enum4linux-ng`;
- `smbclient`;
- `ldap-utils`;
- `evil-winrm`;
- `coercer`;
- `bloodyAD`;
- `pywhisker`.

O projeto documenta que `crackmapexec` é legado e deve ser substituído por alternativa mantida quando validada.

### `modules/20-install-osint-tools.sh`

Módulo planejado para OSINT autorizado.

Escopo documentado:

- `theHarvester`;
- Shodan CLI;
- Censys CLI;
- SpiderFoot quando validado;
- utilitários de enriquecimento.

Deve separar ferramentas que exigem API keys e documentar limites de privacidade.

### `modules/21-install-cloud-tools.sh`

Módulo planejado para Cloud Security.

Escopo documentado:

- `awscli`;
- `azure-cli`;
- `gcloud`;
- `scoutsuite`;
- `prowler`;
- `roadrecon`;
- `checkov`;
- ferramentas IaC.

Não deve armazenar credenciais cloud em texto puro.

### `modules/22-install-mobile-tools.sh`

Módulo planejado para análise mobile autorizada.

Escopo documentado:

- `apktool`;
- `jadx`;
- `frida-tools`;
- `objection`;
- Android platform-tools;
- MobSF em ambiente isolado.

### `modules/23-install-wireless-tools.sh`

Módulo planejado para ferramentas wireless.

Escopo documentado:

- `aircrack-ng`;
- `kismet`;
- `bettercap`;
- utilitários dependentes de hardware compatível.

Deve documentar legalidade, modo monitor, drivers e limitações de VM.

### `modules/24-install-forensics-tools.sh`

Módulo planejado para forense defensiva.

Escopo documentado:

- `sleuthkit`;
- Autopsy quando adequado;
- Volatility;
- `exiftool`;
- `binwalk`;
- ferramentas de imagem.

Deve separar evidência original de cópias de trabalho.

### `modules/25-install-reporting-tools.sh`

Módulo planejado para relatórios.

Escopo documentado:

- `pandoc`;
- LaTeX opcional;
- templates;
- screenshots;
- organização de evidências.

Não deve incluir dados reais de cliente no repositório.

### `modules/26-install-wordlists.sh`

Módulo planejado para wordlists.

Escopo documentado:

- SecLists;
- `rockyou`;
- listas `dirb`;
- listas `dirbuster`;
- listas `wfuzz`;
- Assetnote opcional;
- fuzzdb opcional.

Deve pedir confirmação antes de baixar ou extrair coleções grandes.

### `modules/27-install-lab-environments.sh`

Módulo planejado para laboratórios vulneráveis isolados.

Escopo documentado:

- OWASP Juice Shop;
- DVWA;
- WebGoat;
- crAPI;
- VAmPI;
- labs AD separados.

Deve usar bind em `127.0.0.1` por padrão e evitar exposição pública.

### `modules/28-configure-tool-paths.sh`

Módulo planejado para consolidar PATH.

Escopo documentado:

- `~/.local/bin`;
- `~/go/bin`;
- `~/.cargo/bin`;
- diretórios locais de ferramentas.

Deve ser idempotente e evitar duplicar entradas.

### `modules/29-validate-installation.sh`

Módulo planejado para validação geral.

Escopo documentado:

- `command -v`;
- versões locais;
- permissões;
- diretórios;
- inventário;
- relatório local sem secrets.

Não deve executar scans externos.

### `modules/30-update-security-tools.sh`

Módulo planejado para atualização de ferramentas.

Escopo documentado:

- APT;
- Go;
- pipx;
- Cargo;
- Git;
- logs sem secrets;
- confirmação antes de atualizar.

## Scripts auxiliares

### `scripts/edit-api-keys.sh`

Abre o arquivo real de chaves em editor local seguro.

O que faz:

- valida que está sendo executado pelo usuário esperado;
- localiza `~/.config/kali-setup/api-keys.env`;
- recusa link simbólico;
- valida diretório `700`;
- valida arquivo `600`;
- valida dono e grupo;
- usa `${EDITOR:-nano}`;
- recusa `EDITOR` com espaços para evitar parsing inseguro;
- corrige permissão após edição;
- não imprime secrets.

Uso:

```bash
~/.local/bin/edit-api-keys
```

Com editor específico:

```bash
EDITOR=vim ~/.local/bin/edit-api-keys
```

### `scripts/check-api-keys.sh`

Valida o arquivo real de chaves sem mostrar valores.

O que faz:

- confirma existência do arquivo;
- confirma que é arquivo regular;
- recusa link simbólico;
- valida dono, grupo e permissão;
- valida nomes de variáveis permitidas;
- detecta variáveis duplicadas;
- detecta linhas inválidas;
- contabiliza APIs configuradas e ausentes;
- não faz requisições online na versão atual.

Uso:

```bash
~/.local/bin/check-api-keys
```

### `scripts/export-api-keys.sh`

Exporta chaves para o shell atual de forma controlada.

O que faz:

- valida o arquivo antes de carregar;
- recusa permissões inseguras;
- recusa variáveis desconhecidas;
- faz parsing controlado;
- exporta somente nomes permitidos;
- não usa `eval`;
- não usa `source` direto no arquivo de secrets;
- não imprime valores.

Uso correto:

```bash
source ~/.local/bin/export-api-keys
```

Executar diretamente não funciona para o shell atual, porque variáveis exportadas em processo filho não voltam para o processo pai.

### `scripts/check-tool.sh`

Consulta uma ferramenta específica no inventário.

O que faz:

- procura a ferramenta em todos os inventários;
- mostra categoria, prioridade, método, origem e arquitetura;
- extrai o primeiro comando da coluna de validação;
- usa `command -v` para dizer se a ferramenta está instalada;
- para ferramentas Go, confere primeiro o binário esperado em `~/go/bin`, evitando falsos positivos como o conflito conhecido do `httpx`;
- retorna código `2` quando a ferramenta existe no inventário, mas está ausente no sistema.

Uso:

```bash
scripts/check-tool.sh nuclei
scripts/check-tool.sh nmap
scripts/check-tool.sh subfinder
```

### `scripts/check-all-tools.sh`

Valida todas as ferramentas dos inventários principais.

O que faz:

- percorre `packages-base.txt`;
- percorre `packages-network.txt`;
- percorre `tools-go.txt`;
- percorre `tools-python.txt`;
- percorre `tools-git.txt`;
- percorre `tools-optional.txt`;
- verifica cada comando com `command -v`;
- marca ferramentas Go como `conflito/fora do padrão` quando existe um comando com o mesmo nome no `PATH`, mas o binário esperado não está em `~/go/bin`;
- imprime contagem de instaladas, ausentes e inválidas.

Uso:

```bash
scripts/check-all-tools.sh
```

### `scripts/show-tool-inventory.sh`

Mostra o inventário completo em formato tabular.

O que faz:

- lê inventários de `config/`;
- ignora comentários e linhas vazias;
- valida a quantidade mínima de campos;
- imprime nome, categoria, prioridade, método, origem e arquitetura.

Uso:

```bash
scripts/show-tool-inventory.sh
```

### `scripts/update-go-tools.sh`

Atualiza ferramentas Go `CORE` e `RECOMMENDED`.

O que faz:

- exige `go` no sistema;
- pede confirmação;
- lê `config/tools-go.txt`;
- processa apenas linhas com método `go`;
- atualiza somente prioridades `CORE` e `RECOMMENDED`;
- ignora ferramentas `OPTIONAL` por padrão;
- usa `go install <origem>`.

Uso:

```bash
scripts/update-go-tools.sh
```

### `scripts/update-python-tools.sh`

Atualiza ferramentas Python instaladas por `pipx`.

O que faz:

- exige `pipx`;
- pede confirmação;
- lê `config/tools-python.txt`;
- processa apenas linhas com método `pipx`;
- executa `pipx upgrade <pacote>`.

Uso:

```bash
scripts/update-python-tools.sh
```

### `scripts/update-git-tools.sh`

Lista ferramentas cujo método é `git`.

O que faz:

- lê `config/tools-git.txt`;
- imprime ferramentas marcadas com método `git`;
- não executa `git clone`;
- não executa `git pull`;
- exige revisão manual do repositório oficial antes de qualquer atualização.

Uso:

```bash
scripts/update-git-tools.sh
```

## Arquivos de configuração

### `config/api-keys.env.example`

Modelo público de chaves de API.

Ele documenta variáveis aceitas pelo projeto, sempre com valores vazios.

Exemplos de variáveis:

- `SHODAN_API_KEY`
- `SECURITYTRAILS_API_KEY`
- `VIRUSTOTAL_API_KEY`
- `CENSYS_API_TOKEN`
- `GITHUB_TOKEN`
- `GITLAB_TOKEN`
- `PROJECTDISCOVERY_API_KEY`
- `HUNTER_API_KEY`
- `BUILTWITH_API_KEY`
- `BINARYEDGE_API_KEY`
- `FOFA_EMAIL`
- `FOFA_API_KEY`
- `ZOOMEYE_API_KEY`
- `FULLHUNT_API_KEY`
- `CHAOS_API_KEY`
- `INTELX_API_KEY`
- `URLSCAN_API_KEY`
- `GREYNOISE_API_KEY`
- `ABUSEIPDB_API_KEY`
- `IPINFO_TOKEN`
- `WHOISXML_API_KEY`
- `NETLAS_API_KEY`
- `LEAKIX_API_KEY`
- `PULSEDIVE_API_KEY`
- `ONYPHE_API_KEY`
- `QUAKE_API_KEY`
- `PASSIVETOTAL_USERNAME`
- `PASSIVETOTAL_API_KEY`

O arquivo real fica fora do repositório:

```text
~/.config/kali-setup/api-keys.env
```

### `config/subfinder-provider-config.yaml.example`

Modelo público de provedores do Subfinder.

O Subfinder usa provedores para consultar fontes externas de subdomínios. Algumas fontes aceitam uma chave simples; outras usam credenciais compostas.

O modelo mantém listas vazias para provedores como:

- `binaryedge`
- `builtwith`
- `censys`
- `chaos`
- `fofa`
- `github`
- `hunter`
- `intelx`
- `securitytrails`
- `shodan`
- `virustotal`
- `whoisxmlapi`
- `zoomeyeapi`

O arquivo real fica fora do repositório:

```text
~/.config/subfinder/provider-config.yaml
```

### `config/packages-base.txt`

Inventário de pacotes base instalados pelo módulo `06`.

Formato:

```text
nome|categoria|prioridade|método|pacote-ou-origem|comando-validacao|arquitetura
```

Categorias principais:

- `base`: utilitários essenciais.
- `build`: compilação e headers.
- `python`: runtime Python e isolamento com `pipx`.
- `quality`: ferramentas de qualidade como `shellcheck`.
- `remote`: SSH.
- `network`: rede básica.
- `shell`: melhoria de terminal.

### `config/packages-network.txt`

Inventário de ferramentas de rede instaladas pelo módulo `14`.

Inclui ferramentas de:

- varredura de portas;
- descoberta em rede local;
- captura de pacotes;
- DNS;
- SMB;
- SNMP;
- IKE/IPsec;
- TLS;
- LDAP;
- clientes de banco de dados.

### `config/tools-go.txt`

Inventário de ferramentas Go usadas principalmente pelos módulos `11` e `15`.

Métodos possíveis nesse arquivo:

- `go`: instalar com `go install`.
- `apt`: instalar via pacote Kali quando disponível.

Ferramentas centrais:

- `subfinder`
- `httpx`
- `dnsx`
- `nuclei`
- `naabu`
- `katana`
- `anew`
- `ffuf`
- `gobuster`
- `feroxbuster`

### `config/tools-python.txt`

Inventário de ferramentas Python usadas pelos módulos `10` e `15`.

Métodos possíveis:

- `apt`: pacote do Kali.
- `pipx`: instalação isolada no usuário.

O projeto prefere `pipx` para ferramentas Python que não precisam ser bibliotecas do sistema.

### `config/tools-git.txt`

Inventário de ferramentas que podem exigir Git ou revisão manual.

Exemplos:

- `testssl.sh`
- `puredns`
- `massdns`
- `httprobe`
- `hakrawler`
- `gau`
- `waybackurls`
- `gospider`
- `gowitness`

O método `git` não é executado automaticamente pelo módulo `15`, porque clonar e atualizar repositórios externos exige revisão de origem, manutenção e compatibilidade.

### `config/tools-optional.txt`

Inventário extra de ferramentas opcionais.

Inclui:

- `rustscan`
- `feroxbuster`
- `docker.io`
- `docker-compose`
- `docker-compose-plugin`
- `wireshark`
- `tshark`
- `termshark`
- `scoutsuite`
- `roadrecon`

Serve como referência complementar para manutenção e validação.

### `config/tools-disabled.txt`

Inventário de ferramentas legadas, desabilitadas ou a confirmar.

Inclui:

- `aquatone`
- `crackmapexec`
- `ripgen`
- `rusthound-ce`
- `findomain`
- `eyewitness`
- `urldedupe`

Essas ferramentas não são instaladas automaticamente porque podem estar sem manutenção, ter compatibilidade incerta, possuir substitutos melhores ou exigir validação adicional.

### `config/engagement-template/README.md`

Explica como usar a estrutura de engagement.

Reforça que dados reais de cliente não devem ser colocados no repositório e que a estrutura deve ser copiada para um local apropriado somente após autorização formal.

### `config/engagement-template/*/.gitkeep`

Arquivos vazios usados para manter diretórios vazios versionados no Git.

Eles não têm função operacional. Podem continuar vazios.

## Documentação complementar

### `docs/API-KEYS.md`

Documentação específica sobre chaves de API.

Explica:

- o que são API keys, tokens, PATs e credenciais compostas;
- onde os arquivos reais ficam;
- como editar, validar e carregar variáveis;
- como evitar vazamento em Git, terminal, logs, prints e mensagens;
- como revogar e rotacionar chaves;
- quais serviços são prioritários.

### `docs/AUTHORIZED-USE.md`

Documento de uso autorizado.

Serve para reforçar limites éticos e legais do projeto: usar ferramentas apenas em ambiente próprio, laboratório ou escopo com permissão explícita.

### `docs/INSTALLATION.md`

Guia de instalação.

Complementa o README com orientações de preparação inicial, ordem de módulos e cuidados antes de executar alterações no sistema.

### `docs/MAINTENANCE.md`

Guia de manutenção.

Documenta como manter inventários, atualizar ferramentas e preservar o padrão do projeto.

### `docs/TOOL-INVENTORY.md`

Resumo do inventário de ferramentas.

Explica o formato:

```text
nome|categoria|prioridade|método|pacote-ou-origem|comando-validacao|arquitetura
```

Também resume ferramentas importantes e como visualizar o inventário local.

### `docs/TROUBLESHOOTING.md`

Guia de resolução de problemas.

Deve ser usado quando módulos falham por permissões, ausência de comandos, problemas de APT, chaves de API mal formatadas ou incompatibilidade de ambiente.

### `docs/USO-DAS-FERRAMENTAS.md`

Guia prático de uso das ferramentas.

Explica, em ordem de uso, para que cada ferramenta serve, qual comando inicial executar e qual saída ilustrativa esperar. Também diferencia ferramentas centrais, opcionais, legadas e desabilitadas.

## Como ler os inventários

Todos os inventários usam o mesmo formato:

```text
nome|categoria|prioridade|método|pacote-ou-origem|comando-validacao|arquitetura
```

Campos:

- `nome`: nome amigável da ferramenta.
- `categoria`: área de uso, como `dns`, `http`, `network`, `cloud`, `urls`.
- `prioridade`: define se instala automaticamente, pergunta ou ignora.
- `método`: forma de instalação ou tratamento.
- `pacote-ou-origem`: pacote APT, módulo Go, pacote pipx ou URL.
- `comando-validacao`: comando usado para detectar se a ferramenta existe.
- `arquitetura`: observação sobre compatibilidade, especialmente ARM64.

Prioridades:

- `CORE`: ferramenta essencial instalada pelo módulo responsável.
- `RECOMMENDED`: ferramenta recomendada para workstation profissional.
- `OPTIONAL`: ferramenta útil, mas exige confirmação.
- `LEGACY`: documentada, mas não instalada.
- `UNSUPPORTED`: recusada até nova validação.

Métodos:

- `apt`: instala via APT/Kali.
- `go`: instala via `go install`.
- `pipx`: instala isolado via `pipx`.
- `git`: exige revisão manual.
- `disabled`: não instala.

## Ferramentas usadas pelo próprio projeto

Além das ferramentas de pentest, os scripts usam comandos administrativos do Linux.

### Bash e segurança de script

- `bash`: interpretador usado por todos os scripts.
- `set -Eeuo pipefail`: faz o script falhar em erro, variável não definida e falhas em pipeline.
- `trap ERR`: captura erros e imprime contexto.
- `umask 077`: cria arquivos privados por padrão.
- `printf`: saída previsível e portável.
- `read -r`: leitura segura de confirmações.
- `case`: valida escolhas sem precisar de `eval`.

### Usuários, grupos e permissões

- `id`: identifica usuário atual.
- `getent`: consulta usuários e grupos via NSS.
- `usermod`: adiciona usuário a grupos, como `sudo` ou `docker`.
- `deluser`: remove usuário.
- `delgroup`: remove grupo residual quando seguro.
- `chmod`: ajusta permissões.
- `chown`: ajusta dono e grupo.
- `stat`: lê permissões, dono e grupo.
- `pgrep`: localiza processos de usuário.
- `pkill`: encerra processos antes de remoção de usuário.

### Arquivos e diretórios

- `mkdir`: cria diretórios.
- `cp`: cria backups preservando metadados.
- `mv`: troca arquivos preparados de forma controlada.
- `mktemp`: cria arquivos temporários seguros.
- `basename`: monta nomes de backup.
- `grep`: valida conteúdo e busca marcadores.

### Sistema, hostname e serviços

- `hostname`: consulta hostname ativo.
- `hostnamectl`: altera hostname estático/transiente em sistemas com systemd.
- `systemctl`: habilita e inicia serviços, como Docker.
- `uname`: detecta arquitetura.
- `date`: gera timestamps de logs e backups.

### APT e pacotes

- `apt update`: atualiza índices de pacote.
- `apt full-upgrade`: aplica upgrade completo quando confirmado.
- `apt autoremove`: remove dependências órfãs quando confirmado.
- `apt autoclean`: limpa cache antigo.
- `apt-cache show`: valida existência de pacote.
- `dpkg-query`: verifica se pacote está instalado.
- `dpkg --audit`: procura pacotes quebrados.
- `apt-get check`: valida consistência de dependências.

### Qualidade e validação

- `bash -n`: valida sintaxe sem executar.
- `shellcheck`: ferramenta opcional para análise estática de Bash.
- `command -v`: verifica se comandos existem no `PATH`.
- `rg`: ferramenta rápida de busca textual instalada como `ripgrep`.

## Ferramentas de segurança e uso previsto

Esta seção resume o uso das ferramentas presentes nos inventários.

### Base e produtividade

- `curl` e `wget`: downloads HTTP/HTTPS controlados.
- `git`: versionamento e obtenção de projetos quando revisados.
- `jq`: processamento JSON.
- `yq`: processamento YAML.
- `zip`, `unzip`, `tar`, `gzip`, `bzip2`, `xz-utils`, `p7zip-full`: compactação e extração.
- `file`: identificação de tipo de arquivo.
- `rsync`: cópia eficiente de diretórios.
- `ripgrep`: busca rápida em código e logs.
- `fd-find`: busca rápida de arquivos.
- `fzf`: seleção interativa no terminal.
- `tmux` e `screen`: sessões persistentes.
- `nano` e `vim`: edição de arquivos.
- `less` e `man-db`: leitura de documentação local.
- `shellcheck`: revisão estática de scripts Bash.

### Compilação e runtimes

- `build-essential`, `gcc`, `g++`, `make`: compilação básica.
- `cmake`: build system usado por vários projetos.
- `pkg-config`: descoberta de bibliotecas.
- `libssl-dev`: headers para OpenSSL.
- `libffi-dev`: interface FFI para pacotes Python.
- `libpcap-dev`: captura de pacotes, necessária por algumas ferramentas de rede.
- `python3`, `python3-venv`, `python3-dev`: runtime e ambientes Python.
- `pipx`: instalação isolada de ferramentas Python.
- `golang-go`: runtime e compilador Go.
- `cargo` e `rustc`: runtime e compilador Rust.

### Rede e enumeração

- `nmap`: enumeração de portas e serviços.
- `masscan`: varredura rápida, sempre com limite de taxa e escopo.
- `arp-scan` e `netdiscover`: descoberta em rede local.
- `fping`: checagem de múltiplos hosts.
- `hping3`: testes TCP/IP avançados.
- `tcpdump`, `wireshark`, `tshark`, `termshark`: captura e análise de pacotes.
- `proxychains4`: execução de ferramentas por cadeia de proxies.
- `dnsutils`, `dnsrecon`, `dnsenum`, `dnsx`: consultas e enumeração DNS.
- `enum4linux-ng`, `smbclient`, `rpcclient`: enumeração SMB/Windows.
- `snmp`, `onesixtyone`: enumeração SNMP.
- `ike-scan`: enumeração VPN/IPsec.
- `sslscan` e `testssl.sh`: análise TLS/SSL.
- `ldap-utils`: consultas LDAP.
- `redis-tools`, `postgresql-client`, `default-mysql-client`: clientes para validação local ou autorizada de serviços.

### Reconhecimento Web, DNS e OSINT

- `subfinder`: descoberta passiva de subdomínios.
- `assetfinder`: descoberta adicional de ativos.
- `chaos-client`: consulta Chaos ProjectDiscovery.
- `httpx`: valida hosts HTTP/HTTPS e coleta tecnologias.
- `katana`: crawling web.
- `hakrawler` e `gospider`: crawling complementar.
- `gau`, `waybackurls`, `waymore`: coleta de URLs históricas.
- `unfurl`, `qsreplace`, `uro`: tratamento, extração e normalização de URLs.
- `anew`: deduplicação incremental.
- `ffuf`, `gobuster`, `feroxbuster`: descoberta de conteúdo e fuzzing autorizado.
- `wafw00f`: detecção de WAF.
- `arjun`: descoberta de parâmetros HTTP.
- `sqlmap`: validação autorizada de SQL injection.
- `theHarvester`, `shodan`, `censys`, `uncover`: inteligência e OSINT.

### Vulnerabilidades e validação

- `nuclei`: execução de templates para validação de exposições e vulnerabilidades em escopo autorizado.
- `cvemap`: consulta e organização de CVEs.
- `detect-secrets`: detecção defensiva de secrets.
- `semgrep`: análise estática de código.
- `checkov`: análise de infraestrutura como código e cloud.

### Active Directory e ambientes corporativos

- `impacket`: conjunto de ferramentas para protocolos Microsoft.
- `enum4linux-ng`: enumeração SMB.
- `smbclient`: interação com compartilhamentos SMB.
- `ldap-utils`: consultas LDAP.
- Ferramentas como BloodHound, NetExec, Certipy e Kerbrute estão planejadas no módulo `19`.

### Cloud

- `scoutsuite`: auditoria cloud.
- `roadrecon`: enumeração Azure/Entra ID.
- `checkov`: validação de IaC.
- AWS, Azure e GCP CLIs estão planejadas no módulo `21`.

### Containers e laboratórios

- `docker.io`: engine Docker no Kali.
- `docker-compose-plugin`: Compose integrado ao Docker.
- `docker-compose`: fallback quando o plugin não está disponível.

Docker será usado futuramente para laboratórios locais como Juice Shop, DVWA, WebGoat e crAPI, sempre isolados e preferencialmente expostos apenas em `127.0.0.1`.

### Ferramentas desabilitadas ou legadas

- `aquatone`: legado; não instalar sem revisar manutenção.
- `crackmapexec`: legado; preferir alternativa mantida quando validada.
- `ripgen`: não suportado até validação.
- `rusthound-ce`: não suportado até validação.
- `findomain`: confirmar suporte e manutenção.
- `eyewitness`: confirmar compatibilidade atual.
- `urldedupe`: confirmar origem e manutenção.

## Chaves de API

Fluxo recomendado:

```bash
sudo ./modules/04-configure-api-keys.sh
~/.local/bin/edit-api-keys
~/.local/bin/check-api-keys
source ~/.local/bin/export-api-keys
```

Validar se uma variável foi carregada sem mostrar valor:

```bash
if [[ -n "${SHODAN_API_KEY:-}" ]]; then
    printf '%s\n' 'SHODAN_API_KEY configurada'
fi
```

Regras de segurança:

- não coloque chaves reais em `config/api-keys.env.example`;
- não coloque chaves reais em `README.md` ou `docs/`;
- não passe secrets por argumento de linha de comando;
- não use `set -x` com secrets;
- não publique prints contendo tokens;
- revogue imediatamente qualquer chave vazada.

## Validação e manutenção

Validar sintaxe:

```bash
./install.sh --validate
```

Mostrar inventário:

```bash
scripts/show-tool-inventory.sh
```

Checar uma ferramenta:

```bash
scripts/check-tool.sh nuclei
```

Checar todas as ferramentas:

```bash
scripts/check-all-tools.sh
```

Atualizar ferramentas Go:

```bash
scripts/update-go-tools.sh
```

Atualizar ferramentas Python via pipx:

```bash
scripts/update-python-tools.sh
```

Listar ferramentas Git que exigem revisão manual:

```bash
scripts/update-git-tools.sh
```

Antes de commitar:

```bash
git status
git diff --cached
git grep 'API_KEY'
```

Se uma chave real aparecer em qualquer saída, revogue a chave no serviço oficial imediatamente.

## O que o projeto não faz automaticamente

O KALI SETUP não:

- executa pentest contra alvos;
- valida chaves de API online;
- instala ferramentas legadas marcadas como `LEGACY`;
- instala ferramentas marcadas como `UNSUPPORTED`;
- executa `git clone` de ferramentas externas sem revisão;
- baixa coleções grandes de wordlists sem etapa planejada;
- expõe laboratórios vulneráveis publicamente;
- publica nada no GitHub;
- cria commits automaticamente;
- substitui leitura de documentação oficial das ferramentas.

## Boas práticas do projeto

- Uma responsabilidade por módulo.
- Backups antes de modificar arquivos sensíveis.
- Validação antes de remoção.
- Nada de secrets no Git.
- Nada de `eval`.
- Nada de `source` direto em arquivo de secrets.
- Nada de `sudo pip install`.
- Preferência por APT, `pipx`, `go install` e `cargo` com confirmação.
- Logs privados fora do repositório.
- Confirmação antes de ações sensíveis.
- Uso somente em ambiente autorizado.
