#!/bin/bash
#
# NAME
#   one-flush-iptables.sh - drop obsolete OpenNebula iptables rules
#
# SYNOPSIS
#   one-flush-iptables.sh [-f] [domain]
#
# DESCRIPTION
#   "one-flush-iptables.sh" is a shell script which can be used
#   to find the iptables rules for inactive libvirt domains
#   created by the OpenNebula. It can easily happen that OpenNebula
#   fails to clean the domain properly and obsolete rules on virtual
#   network interfaces (vnet*) can break future libvirt domains,
#   which reuse these interfaces.
#
# OPTIONS
#   -f 
#     Obsolete rules are logged via syslog and dropped. If -f is not
#     specified, script ONLY WRITES obsolete rules on stdout without
#     taking any action.
#
#   domain
#     Clean iptables rules only for one particular domain. Otherwise
#     rules of all inactive domains are deleted.
#
###########################################################################

if [ "x${1}" = 'x-f' ]; then
	FORCE=1
	shift
else
	FORCE=
	echo 'WARNING: Use -f to flush following rules'
fi

NAME=$(basename ${0})
IPTABLES='iptables -w10'
DOMAIN="${1}"

#####

log() {
	echo "${1}"
	if [ -n "${FORCE}" ]; then
		logger -t "${NAME}" "${1}"
	fi
}

iptables_clean() {
	DOMAIN="${1}"
	log "Flushing domain ${DOMAIN}"

	# cleanup FORWARD chain rules, e.g.:
	# -A FORWARD -m physdev --physdev-out vnet4 --physdev-is-bridged -j one-20732-13
	while IFS= read -r LINE; do
		log "rule: ${LINE}"
		[ -n "${FORCE}" ] && ${IPTABLES} -D ${LINE/#-A/}
	done < <(${IPTABLES} -S FORWARD 2>/dev/null | egrep "${DOMAIN}-")

	# cleanup opennebula chain rules, e.g.:
	# -A opennebula -m physdev --physdev-in vnet5 --physdev-is-bridged -j one-23227-5-o
	while IFS= read -r LINE; do
		log "rule: ${LINE}"
		[ -n "${FORCE}" ] && ${IPTABLES} -D ${LINE/#-A/}
	done < <(${IPTABLES} -S opennebula 2>/dev/null | egrep "${DOMAIN}-")

	# drop domain chains
	for CHAIN in $(${IPTABLES} -S 2>/dev/null | egrep "^-N ${DOMAIN}-" | sed -e 's/^-N //'); do
		log "chain: ${CHAIN}"
		[ -n "${FORCE}" ] && \
			${IPTABLES} -F ${CHAIN} && \
			${IPTABLES} -X ${CHAIN}
	done
}

##### Main

if [ "x${DOMAIN}" != 'x' ]; then
	iptables_clean "${DOMAIN}"
else
	DOMAINS=( $(virsh -r list --name) )
	for DOMAIN in $(${IPTABLES} -n -L | sed -e "s/^.*\(one-[0-9]*\)-.*$/\1/;tx;d;:x" | sort -u); do
		case "${DOMAINS[@]}" in *"${DOMAIN}"*) continue;; esac
		iptables_clean "${DOMAIN}"
	done
fi
