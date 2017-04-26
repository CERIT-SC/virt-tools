#!/bin/bash

NAME=$(basename ${0})
MTU=${MTU:-1500}
IFACES=${IFACES:-$(ifconfig -a 2>/dev/null | grep mtu | cut -d: -f1)}

if [ ! -f /etc/redhat-release ]; then
	echo 'ERROR: RedHat like system required' >&2
	exit 1
fi

if [ "x${1}" = 'x-f' ]; then
	FORCE=1
	shift
else
	FORCE=
	echo 'WARNING: Use -f to fix following rules'
fi


#####

log() {
	echo "${1}"
	if [ -n "${FORCE}" ]; then
		logger -t "${NAME}" "${1}"
	fi
}

fix_mtu() {
	RETURN=1

	for IFACE in ${IFACES}; do
		[ "${IFACE}" = 'lo' ] && continue
		[[ "${IFACE}" =~ ^ib ]] && continue

		IFCFG="/etc/sysconfig/network-scripts/ifcfg-${IFACE}"
		CONF_MTU=$(egrep -i '^MTU\s*=' "${IFCFG}" 2>/dev/null | sed -e 's/.*=//')
		CONF_MTU=${CONF_MTU:-$MTU}
		HAVE_MTU=$(ifconfig ${IFACE} 2>/dev/null | grep mtu | sed -e 's/.*mtu //')

		if [ "${CONF_MTU}" != "${HAVE_MTU}" ]; then
			log "Fix ${IFACE} current MTU ${HAVE_MTU} to ${CONF_MTU}"
			if [ -n "${FORCE}" ]; then
				ifconfig ${IFACE} mtu ${CONF_MTU}
				RETURN=0
			fi
		fi
	done

	return ${RETURN}
}

COUNT=$(echo "${IFACES}" | wc -w)
while fix_mtu; do
	if [ ${COUNT} -gt 0 ]; then
		log "Checking again ... ${COUNT}"
		COUNT=$((COUNT-1))
		sleep 1
	else
		log 'ERROR: Maximum checks reached' >&2
		exit 1
	fi
done
