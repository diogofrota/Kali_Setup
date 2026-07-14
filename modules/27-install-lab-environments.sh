#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 27
# NOME..........: Laboratórios vulneráveis - Planejado
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 0.1
#
# OBJETIVO
#
# Documentar o módulo futuro para laboratórios vulneráveis locais e isolados
# usados em estudo e prática autorizada.
#
# FLUXO DE EXECUÇÃO PLANEJADO
#
# 1. Validar Docker e redes locais restritas.
# 2. Baixar ou preparar laboratórios conhecidos.
# 3. Expor serviços apenas em loopback por padrão.
# 4. Registrar comandos de início, parada e limpeza.
#
# RISCOS CONTROLADOS
#
# Aplicações vulneráveis não devem ficar expostas publicamente. O módulo deve
# usar 127.0.0.1 por padrão e exigir confirmação para qualquer exposição maior.
###############################################################################

set -Eeuo pipefail
umask 077

printf '\n%s\n%s\n%s\n%s\n\n' '============================================================' '            KALI SETUP - MÓDULO 27' '              Laboratórios - Planejado' '============================================================'
printf '%s\n' 'Objetivo: preparar laboratórios vulneráveis isolados para estudo autorizado.'
printf '%s\n' 'Escopo: OWASP Juice Shop, DVWA, WebGoat, crAPI, VAmPI e labs AD separados.'
printf '%s\n' 'Dependências planejadas: módulo 13 e redes Docker restritas.'
printf '%s\n' 'TODO: usar bind 127.0.0.1 por padrão e nunca expor apps vulneráveis em 0.0.0.0 sem confirmação.'
