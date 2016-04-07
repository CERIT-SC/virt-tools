#!/bin/bash
#
# NAME
#   virt-patch-pty-channels.sh - change domain channel from PTY to UNIX
#
# SYNOPSIS
#   virt-patch-pty-channels.sh [domain] [domain] ...
#
# DESCRIPTION
#   "virt-patch-pty-channels.sh" is a shell script which checks all or provided
#   domains for channel devices on PTY. These devices are live replaced
#   (hotunplugged and hotplugged) with UNIX type channels with same names.
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
which virsh virt-xml xmllint >/dev/null || exit 1

RETURN=0
DOMAINS=${@:-$(virsh -r list --state-running --name)}
for DOMAIN in ${DOMAINS}; do
	# get pty channel names
	CHANNELS=$(virsh -r dumpxml "${DOMAIN}" | \
		xmllint --xpath '//domain//devices//channel[@type="pty"]//target//@name' - 2>/dev/null |
		sed -e 's/name="\([^"]*\)"/\1/g')

	# try to fix each channel
	for CHANNEL in ${CHANNELS}; do
		virt-xml "${DOMAIN}" --remove-device --channel "pty,name=${CHANNEL}" --update &>/dev/null && \
			virt-xml "${DOMAIN}" --add-device --channel "unix,name=${CHANNEL}" --update &>/dev/null

		if [ $? -eq 0 ]; then
			echo "Patched ${DOMAIN} on ${CHANNEL}"
		else 
			echo "Failure ${DOMAIN} on ${CHANNEL}" >&2
			RETURN=1
		fi
	done
done

exit ${RETURN}
