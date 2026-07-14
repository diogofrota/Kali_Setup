#!/usr/bin/env bash

###############################################################################
# KALI SETUP
#
# MÓDULO........: 19
# NOME..........: Active Directory - Planejado
# AUTOR.........: Diogo Frota
# SISTEMA.......: Kali Linux / Debian
# VERSÃO........: 0.1
#
# OBJETIVO
#
# Documentar o módulo futuro para ferramentas de enumeração e auditoria Active
# Directory em ambientes corporativos autorizados.
#
# FLUXO DE EXECUÇÃO PLANEJADO
#
# 1. Validar ferramentas mantidas e fontes oficiais.
# 2. Preferir alternativas atuais a ferramentas legadas.
# 3. Instalar clientes e utilitários sem executar enumeração automaticamente.
# 4. Registrar dependências e comandos de validação.
#
# RISCOS CONTROLADOS
#
# Ferramentas AD podem acionar alertas e interagir com autenticação corporativa.
# O módulo deve exigir autorização formal e evitar ações automáticas em domínio.
###############################################################################

set -Eeuo pipefail
umask 077

printf '\n%s\n%s\n%s\n%s\n\n' '============================================================' '            KALI SETUP - MÓDULO 19' '       Active Directory - Planejado' '============================================================'
printf '%s\n' 'Objetivo: preparar ferramentas para enumeração e auditoria AD autorizada.'
printf '%s\n' 'Escopo: impacket, netexec, bloodhound, bloodhound-ce, certipy-ad, kerbrute, responder, enum4linux-ng, smbclient, ldap-utils, evil-winrm, coercer, bloodyAD e pywhisker quando mantidos.'
printf '%s\n' 'Dependências planejadas: módulos 10, 11, 13, 14 e documentação oficial de cada projeto.'
printf '%s\n' 'TODO: preferir NetExec ao CrackMapExec legado e validar coletores atuais do BloodHound.'
