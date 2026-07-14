#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 20
# NOME..........: OSINT - Planejado
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 0.1
#
# OBJETIVO
#
# Documentar o módulo futuro para ferramentas OSINT usadas em fontes públicas e
# escopos permitidos, incluindo ferramentas que dependem de chaves de API.
#
# FLUXO DE EXECUÇÃO PLANEJADO
#
# 1. Separar ferramentas que exigem API das que não exigem.
# 2. Validar configuração segura de chaves.
# 3. Instalar ferramentas sem coletar dados automaticamente.
# 4. Documentar privacidade, limites e termos de uso.
#
# RISCOS CONTROLADOS
#
# OSINT pode envolver dados pessoais e limites de serviços externos. O módulo
# deve respeitar autorização, privacidade e limites de API.
###############################################################################

set -Eeuo pipefail
umask 077

printf '\n%s\n%s\n%s\n%s\n\n' '============================================================' '            KALI SETUP - MÓDULO 20' '                OSINT - Planejado' '============================================================'
printf '%s\n' 'Objetivo: instalar ferramentas OSINT para uso autorizado e fontes públicas permitidas.'
printf '%s\n' 'Escopo: theHarvester, shodan CLI, censys CLI, SpiderFoot quando validado e utilitários de enriquecimento.'
printf '%s\n' 'Dependências planejadas: módulos 04, 10, 15.'
printf '%s\n' 'TODO: separar ferramentas que exigem API, documentar privacidade e evitar coleta fora do escopo.'
