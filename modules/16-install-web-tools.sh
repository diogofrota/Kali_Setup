#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 16
# NOME..........: Ferramentas Web - Planejado
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 0.1
#
# OBJETIVO
#
# Documentar o módulo futuro responsável por ferramentas Web usadas em testes
# autorizados, como proxies, scanners leves, fuzzers e navegadores.
#
# FLUXO DE EXECUÇÃO PLANEJADO
#
# 1. Validar fontes oficiais e compatibilidade ARM64.
# 2. Separar ferramentas CORE, RECOMMENDED e OPTIONAL.
# 3. Instalar ferramentas Web sem iniciar scanners automaticamente.
# 4. Registrar resumo e próximos passos.
#
# RISCOS CONTROLADOS
#
# Ferramentas Web podem gerar tráfego ativo. O módulo planejado não deverá
# iniciar varreduras contra alvos públicos nem instalar software licenciado sem
# autorização.
###############################################################################

set -Eeuo pipefail
umask 077

printf '\n%s\n%s\n%s\n%s\n\n' '============================================================' '            KALI SETUP - MÓDULO 16' '             Ferramentas Web - Planejado' '============================================================'
printf '%s\n' 'Objetivo: instalar ferramentas Web autorizadas como Burp Community, ZAP, ffuf, feroxbuster, gobuster, nikto, sqlmap, arjun, wafw00f, whatweb, wpscan, mitmproxy, chromium e firefox-esr.'
printf '%s\n' 'Escopo: não instalar Burp Professional, não burlar licenças e não iniciar scanners contra alvos públicos.'
printf '%s\n' 'Dependências planejadas: módulos 06, 10, 11, 12, 15 e validação de fontes oficiais.'
printf '%s\n' 'TODO: confirmar método oficial atual, classificar ARM64, separar CORE/RECOMMENDED/OPTIONAL e validar comandos locais.'
