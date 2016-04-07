#!/bin/bash
#
# NAME
#   virt-check-bridge-macs.sh - check if VM MACs are on expected bridge ports
#
# SYNOPSIS
#   virt-check-bridge-macs.sh [domain] [domain] ...
#
# DESCRIPTION
#   "virt-check-bridge-macs.sh" is a shell script which checks all or provided
#   domain's network interfaces MACs if they are seen on bridge interfaces
#   they should be. With this check the MAC collision can be detected.
#
# OPTIONS
#   domain
#     If space separated list of domains is provided, only these are checked.
#     Otherwise all "running" domains are checked.
#
# EXIT STATUS
#   0 - if everything OK
#   1 - if there were any problem
#
###########################################################################


# check for required commands
which virsh brctl >/dev/null || exit 1

RETURN=0
DOMAINS=${@:-$(virsh -r list --state-running --name)}
for DOMAIN in ${DOMAINS}; do
	while read IFACE TYPE SOURCE MODEL MAC; do
		[ "x${TYPE}" != 'xbridge' ] && continue

		# get bridge port where we see VM's MAC
		BRPORT=$(brctl showmacs "${SOURCE}" | grep -i "${MAC}" | awk '{ print $1 }')
		[ "x${BRPORT}" == 'x' ] && continue

		# check bridge port interface
		BRIFACE=$(brctl showstp ${SOURCE} | egrep "^.* \(${BRPORT}\)" | awk '{ print $1 }')
		if [ "x${IFACE}" != "x${BRIFACE}" ]; then
			echo "${DOMAIN}: ${MAC} on ${BRIFACE} instead of ${IFACE}" >&2
			RETURN=1
		fi
	done < <(virsh -r --quiet domiflist "${DOMAIN}")
done

exit ${RETURN}
