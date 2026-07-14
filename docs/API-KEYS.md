# KALI SETUP - Chaves de API

Este documento explica como o KALI SETUP organiza chaves de API para uso em reconhecimento, OSINT, Bug Bounty, Red Team autorizado e estudos. Ele não contém credenciais reais e não deve ser usado para armazenar secrets.

## Por que APIs são usadas

Ferramentas de reconhecimento consultam fontes externas para descobrir domínios, subdomínios, tecnologias, certificados, ASN, reputação de IPs, histórico de DNS e indicadores de ameaça. Sem API, muitas ferramentas funcionam com fontes públicas limitadas; com API, elas podem acessar dados autenticados, limites maiores ou bases privadas, sempre respeitando regras do serviço e autorização do alvo.

## Tipos de credencial

- API key: string usada por um serviço para autenticar chamadas simples.
- Token: credencial opaca usada para autorizar acesso a uma API ou CLI.
- Personal Access Token: token emitido para uma conta de usuário, comum em GitHub e GitLab.
- API ID e secret: par composto, geralmente no formato `ID:SECRET` em integrações.
- Usuário e chave: par composto, geralmente no formato `USUARIO:CHAVE`.
- OAuth: fluxo de autorização com consentimento, tokens temporários e escopos.
- Credencial composta: valor formado por duas ou mais partes, como `EMAIL:CHAVE`.

## Onde ficam os arquivos reais

O arquivo principal fica fora do repositório:

```text
~/.config/kali-setup/api-keys.env
```

A configuração real do Subfinder fica em:

```text
~/.config/subfinder/provider-config.yaml
```

Esses arquivos não ficam no Git porque secrets publicados podem ser copiados por terceiros, indexados por plataformas, armazenados em caches e preservados no histórico mesmo depois de removidos do commit mais recente.

## Como preparar, editar, verificar e carregar

Criar a estrutura segura fora do repositório:

```bash
sudo ./modules/04-configure-api-keys.sh
```

Esse módulo cria diretórios privados, instala os utilitários em `~/.local/bin` e prepara a configuração do Subfinder sem mostrar credenciais.

Editar sem imprimir secrets:

```bash
~/.local/bin/edit-api-keys
```

Verificar estrutura, permissões e variáveis sem exibir valores:

```bash
~/.local/bin/check-api-keys
```

Carregar variáveis no shell atual:

```bash
source ~/.local/bin/export-api-keys
```

O exportador aceita apenas linhas no formato controlado:

```text
NOME_VARIAVEL="valor"
```

Ele não executa o conteúdo como Bash. Por segurança, cada variável precisa estar em uma única linha, com nome autorizado pela allowlist e valor delimitado por aspas duplas.

Conferir se uma variável foi carregada sem mostrar o valor:

```bash
if [[ -n "${SHODAN_API_KEY:-}" ]]; then
    printf '%s\n' 'configurada'
fi
```

## Permissões seguras

Diretórios que contêm secrets devem usar permissão `700`: somente o proprietário consegue listar, entrar e alterar.

Arquivos com secrets devem usar permissão `600`: somente o proprietário consegue ler e escrever.

O proprietário esperado neste projeto é:

```text
diogo:diogo
```

## Revogação e rotação

Se uma chave foi exposta, revogue imediatamente no painel oficial do serviço. Não confie apenas em apagar o arquivo local, remover um commit ou trocar o nome da variável.

Para rotacionar:

1. Crie uma nova chave no serviço oficial.
2. Atualize `~/.config/kali-setup/api-keys.env`.
3. Rode `~/.local/bin/check-api-keys`.
4. Atualize integrações que dependam da chave antiga.
5. Revogue a chave antiga.

Checklist prática para cadastrar uma chave:

1. Criar conta no serviço oficial.
2. Ativar MFA sempre que o serviço permitir.
3. Criar token com privilégio mínimo.
4. Copiar a chave somente uma vez.
5. Executar `~/.local/bin/edit-api-keys`.
6. Colar o valor no arquivo protegido.
7. Executar `~/.local/bin/check-api-keys`.
8. Revogar imediatamente se houver exposição.

## Evite exposição

Não coloque secrets em Git, GitHub, arquivos de log, histórico do shell, screenshots, terminal compartilhado, Markdown, Obsidian, mensagens, tickets, comandos com parâmetros visíveis ou exemplos de `curl` colados em chats.

Antes de commitar, revise com cuidado:

```bash
git status
git diff --cached
git grep 'API_KEY'
git log -p
```

`git grep` e `git log -p` podem revelar secrets se eles já estiverem no repositório ou no histórico. Use-os em ambiente privado e revogue qualquer credencial encontrada.

Remover uma chave do commit mais recente não garante remoção do histórico Git. Uma chave exposta deve ser tratada como comprometida e revogada no serviço oficial.

## Prioridade recomendada

Comece por GitHub, Shodan, VirusTotal, SecurityTrails, Censys, ProjectDiscovery, Chaos, URLScan.io, AbuseIPDB e GreyNoise.

A prioridade muda conforme Bug Bounty, pentest interno, OSINT, análise de malware, reconhecimento externo, orçamento, limites de uso e regras do programa.

## Serviços

| Prioridade | Serviço | Finalidade | Variável | Ferramentas | Autenticação | Cadastro oficial | Documentação oficial | Plano |
|---|---|---|---|---|---|---|---|---|
| Alta | GitHub | Busca em código e automações | `GITHUB_TOKEN` | GitHub CLI, scripts, Subfinder | Personal Access Token | https://github.com/settings/tokens | https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens | Freemium |
| Alta | Shodan | Ativos expostos | `SHODAN_API_KEY` | Shodan CLI, Nuclei, scripts | API key | https://account.shodan.io/ | https://developer.shodan.io/ | Freemium/pago |
| Alta | VirusTotal | Reputação e inteligência | `VIRUSTOTAL_API_KEY` | scripts, automações, Subfinder | API key | https://www.virustotal.com/gui/join-us | https://docs.virustotal.com/reference/overview | Freemium/pago |
| Alta | SecurityTrails | DNS e histórico | `SECURITYTRAILS_API_KEY` | Subfinder, Amass, scripts | API key | https://securitytrails.com/ | https://docs.securitytrails.com/ | Avaliação/pago |
| Alta | Censys | Ativos e certificados | `CENSYS_API_TOKEN` | Censys CLI, Subfinder | ID:SECRET ou token conforme API | https://search.censys.io/register | https://docs.censys.com/ | Freemium/pago |
| Alta | ProjectDiscovery Cloud | Plataforma ProjectDiscovery | `PROJECTDISCOVERY_API_KEY` | Nuclei, Uncover, PD Cloud | API key | https://cloud.projectdiscovery.io/ | https://docs.projectdiscovery.io/ | Plano não confirmado |
| Alta | Chaos ProjectDiscovery | Dados de subdomínios | `CHAOS_API_KEY` | Subfinder, scripts | API key | https://chaos.projectdiscovery.io/ | https://docs.projectdiscovery.io/ | Acesso sujeito à aprovação |
| Média | URLScan.io | Análise de URLs | `URLSCAN_API_KEY` | scripts, automações | API key | https://urlscan.io/user/signup | https://urlscan.io/docs/api/ | Freemium |
| Média | AbuseIPDB | Reputação de IPs | `ABUSEIPDB_API_KEY` | scripts, enriquecimento | API key | https://www.abuseipdb.com/register | https://docs.abuseipdb.com/ | Freemium/pago |
| Média | GreyNoise | Contexto de IPs | `GREYNOISE_API_KEY` | scripts, enriquecimento | API key | https://viz.greynoise.io/signup | https://docs.greynoise.io/ | Freemium/pago |
| Média | Hunter | E-mails e domínios | `HUNTER_API_KEY` | OSINT, Subfinder | API key | https://hunter.io/users/sign_up | https://hunter.io/api-documentation | Freemium/pago |
| Média | BuiltWith | Tecnologias web | `BUILTWITH_API_KEY` | Subfinder, scripts | API key | https://builtwith.com/ | https://api.builtwith.com/ | Pago/avaliação |
| Média | BinaryEdge | Ativos expostos | `BINARYEDGE_API_KEY` | Subfinder, scripts | API key | https://app.binaryedge.io/ | https://docs.binaryedge.io/ | Pago/avaliação |
| Média | FOFA | Busca de ativos | `FOFA_EMAIL`, `FOFA_API_KEY` | Subfinder, scripts | EMAIL:CHAVE | https://fofa.info/ | https://en.fofa.info/api | Plano não confirmado |
| Média | ZoomEye | Busca de ativos | `ZOOMEYE_API_KEY` | Subfinder, scripts | host:chave conforme região | https://www.zoomeye.hk/ | https://www.zoomeye.hk/doc | Plano não confirmado |
| Média | FullHunt | Superfície de ataque | `FULLHUNT_API_KEY` | Subfinder, scripts | API key | https://fullhunt.io/ | https://api-docs.fullhunt.io/ | Freemium/pago |
| Média | IPinfo | Enriquecimento de IPs | `IPINFO_TOKEN` | scripts, ferramentas Python | Token | https://ipinfo.io/signup | https://ipinfo.io/developers | Freemium/pago |
| Média | Netlas | Busca de ativos | `NETLAS_API_KEY` | scripts, automações | API key | https://app.netlas.io/registration | https://docs.netlas.io/ | Freemium/pago |
| Média | LeakIX | Serviços expostos | `LEAKIX_API_KEY` | scripts, automações | API key | https://leakix.net/ | https://docs.leakix.net/ | Plano não confirmado |
| Avançada | IntelX | OSINT e inteligência | `INTELX_API_KEY` | Subfinder, scripts | HOST:API_KEY em algumas integrações | https://intelx.io/signup | https://github.com/IntelligenceX/SDK | Pago/avaliação |
| Avançada | WhoisXML API | WHOIS e DNS | `WHOISXML_API_KEY` | Subfinder, scripts | API key | https://whoisxmlapi.com/signup | https://whois.whoisxmlapi.com/api/documentation/making-requests | Pago/avaliação |
| Avançada | PassiveTotal | Infraestrutura e DNS | `PASSIVETOTAL_USERNAME`, `PASSIVETOTAL_API_KEY` | Subfinder, scripts | USUARIO:CHAVE | https://community.riskiq.com/ | https://api.riskiq.net/api/concepts.html | Acesso sujeito à aprovação |
| Avançada | Pulsedive | Inteligência de ameaças | `PULSEDIVE_API_KEY` | scripts, enriquecimento | API key | https://pulsedive.com/register/ | https://pulsedive.com/api/ | Freemium/pago |
| Avançada | ONYPHE | Inteligência de internet | `ONYPHE_API_KEY` | scripts, automações | API key | https://www.onyphe.io/ | https://www.onyphe.io/api | Plano não confirmado |
| Avançada | Quake/360 Quake | Busca de ativos | `QUAKE_API_KEY` | Subfinder, scripts | API key ou composto conforme integração | https://quake.360.net/quake/#/index | https://quake.360.net/quake/#/help | Plano não confirmado |
| Avançada | GitLab | APIs e repositórios | `GITLAB_TOKEN` | GitLab CLI, scripts | Personal Access Token | https://gitlab.com/-/user_settings/personal_access_tokens | https://docs.gitlab.com/user/profile/personal_access_tokens/ | Freemium |

## Integrações futuras

Este módulo prepara a estrutura para Subfinder, Amass, theHarvester, Nuclei, Uncover, Shodan CLI, GitHub CLI, Censys CLI, ferramentas Python, scripts Bash e ferramentas Go. Ele não instala essas ferramentas e não valida credenciais em endpoints externos nesta versão.

Cada ferramenta pode exigir seu próprio arquivo de configuração, formato de variável, escopo de token ou autenticação composta. Antes de automatizar, confira a documentação oficial da versão instalada.
