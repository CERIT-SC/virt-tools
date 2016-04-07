#!/bin/bash
#
# NAME
#   virt-blocked-domains.sh - check for blocked domains
#
# SYNOPSIS
#   virt-blocked-domains.sh [domain] [domain] ...
#
# DESCRIPTION
#   "virt-blocked-domains.sh" is a shell script which checks running domains
#   for aliveness. It can happen the communication with emulator stucks and
#   even whole domain execution can be blocked. We can detect problematic
#   domains with simple request for domain statistics (e.g. domstats or
#   dommemstat). Problematic domain names are then returned on stdout one
#   per line.
#
# OPTIONS
#   domain
#     If space separated list of domains is provided, only these are
#     checked. Otherwise all "running" domains are checked.
#
# EXIT STATUS
#   0 - if everything OK
#   1 - if there are any problematic domain
#
###########################################################################

RETURN=0
TIMEOUT=1
DOMAINS=${@:-$(virsh -r list --state-running --name)}

for DOMAIN in $DOMAINS; do
	timeout ${TIMEOUT} virsh -r dommemstat "${DOMAIN}" &>/dev/null || \
		{
			echo "${DOMAIN}"
			RETURN=1
		}
done

exit ${RETURN}
