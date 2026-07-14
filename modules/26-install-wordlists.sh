#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 26
# NOME..........: Wordlists - Planejado
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 0.1
#
# OBJETIVO
#
# Documentar o módulo futuro para instalação e organização de wordlists usadas
# em laboratórios e escopos autorizados.
#
# FLUXO DE EXECUÇÃO PLANEJADO
#
# 1. Validar espaço em disco disponível.
# 2. Instalar listas comuns por pacote quando possível.
# 3. Perguntar antes de baixar coleções grandes.
# 4. Organizar permissões e caminhos.
#
# RISCOS CONTROLADOS
#
# Wordlists podem consumir muito espaço e conter conteúdo sensível. O módulo
# deve pedir confirmação antes de downloads grandes e extrações pesadas.
###############################################################################

set -Eeuo pipefail
umask 077

printf '\n%s\n%s\n%s\n%s\n\n' '============================================================' '            KALI SETUP - MÓDULO 26' '              Wordlists - Planejado' '============================================================'
printf '%s\n' 'Objetivo: instalar e organizar wordlists usadas em laboratório e escopos autorizados.'
printf '%s\n' 'Escopo: seclists, rockyou, dirb, dirbuster, wfuzz, Assetnote opcional e fuzzdb opcional.'
printf '%s\n' 'Dependências planejadas: módulos 06 e 07.'
printf '%s\n' 'TODO: não extrair rockyou nem baixar coleções grandes sem informar espaço e pedir confirmação.'
