#!/bin/bash

set -e

### Formatting
# command prefixing (source: https://unix.stackexchange.com/a/440514)
prefixWith() {
	local prefix="$1"
	shift

	# redirect standard input and error to different commands (source: https://stackoverflow.com/a/31151808)
	{ "$@" 2>&1 1>&3 3>&- | { while read -r line; do  echo "$prefix $line"; done; }; } 3>&1 1>&2 | { while read -r line; do  echo "$prefix $line"; done; }
}

{ {
	### Sanity Checks
	# username checks
	if [[ -z "${WINDSCRIBE_USERNAME}" ]]; then
	  	prefixWith "[WINDSCRIBE]" echo "Unset Windscribe username; ensure that the environment variable \$WINDSCRIBE_USERNAME is set properly"
		  exit 1
	fi
	if [[ "${WINDSCRIBE_USERNAME}" =~ [^a-zA-Z0-9_] ]]; then
	  	prefixWith "[WINDSCRIBE]" echo "Windscribe username must be alphanumeric (underscores allowed); ensure that the environment variable \$WINDSCRIBE_USERNAME is set properly"
		  exit 1
	fi
	# password checks
	if [[ -z "${WINDSCRIBE_PASSWORD}" ]]; then
	  	prefixWith "[WINDSCRIBE]" echo "Unset Windscribe password; ensure that the environment variable \$WINDSCRIBE_PASSWORD is set properly"
		  exit 1
	fi
	# ensure no newlines present (source: https://unix.stackexchange.com/a/276836)
	NL='
	'
	case "${WINDSCRIBE_PASSWORD}"  in
	  *"${NL}"*) prefixWith "[WINDSCRIBE]" echo "Windscribe password cannot contain new lines; ensure that the environment variable \$WINDSCRIBE_PASSWORD is set properly"
				 exit 1;;
	esac
	# ensure no newlines present
	case "${WINDSCRIBE_LOCATION}"  in
	  *"${NL}"*) prefixWith "[WINDSCRIBE]" echo "Windscribe location cannot contain new lines; ensure that the environment variable \$WINDSCRIBE_LOCATION is set properly"
				 exit 1;;
	esac
	# iptable support checks
	iptables -vnL > /dev/null 2>&1 || {
		prefixWith "[IPTABLES]" echo "Ensure cap_add is set to NET_ADMIN"
		  exit 1
	}


	### Create SSH identity and start OpenSSH server
	# manage SSH identity
	prefixWith "[SSH]" echo "Creating SSH key"
	# generate SSH key
	prefixWith "[SSH]" ssh-keygen -N "" -f "/root/.ssh/id_rsa" <<< y
	# allow self-connecting with SSH
	prefixWith "[SSH]" cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
	# start SSH server
	prefixWith "[SSH]" echo "Starting OpenSSH server"
	prefixWith "[SSH]" service ssh start


	### Create TUN device for Windscribe
	# create TUN device
	prefixWith "[OPENVPN]" echo "Creating OpenVPN TUN device"
	prefixWith "[OPENVPN]" mkdir -p /dev/net
	prefixWith "[OPENVPN]" mknod /dev/net/tun c 10 200
	prefixWith "[OPENVPN]" chmod 600 /dev/net/tun


	### Start Windscribe client
	# define DNS nameservers
	prefixWith "[RESOLV]" echo "Writing /etc/resolv.conf"
	sed -e 's/\s\+/\n/g;s/\(^\|\n\)/\1nameserver /g' <<< "${WINDSCRIBE_DNS:-1.1.1.1}" > "/etc/resolv.conf"
	prefixWith "[RESOLV]" cat /etc/resolv.conf
	# start windscribe daemon
	prefixWith "[WINDSCRIBE]" echo "Starting Windscribe client"
	prefixWith "[WINDSCRIBE]" windscribe start
	# authenticate to Windscribe
	prefixWith "[WINDSCRIBE]" echo "Authenticating to Windscribe"
	prefixWith "[WINDSCRIBE]"  windscribe login <<- EOF
	${WINDSCRIBE_USERNAME}
	${WINDSCRIBE_PASSWORD}
	EOF
	prefixWith "[WINDSCRIBE]" windscribe account
	# connect to Windscribe
	prefixWith "[WINDSCRIBE]" echo "Connecting to Windscribe"
	if [[ -n "${WINDSCRIBE_LOCATION}" ]]; then
		prefixWith "[WINDSCRIBE]" echo "Windscribe location: ${WINDSCRIBE_LOCATION}"
	else
		prefixWith "[WINDSCRIBE]" echo "Windscribe locations:"
		windscribe locations
	fi
	prefixWith "[WINDSCRIBE]" windscribe connect "${WINDSCRIBE_LOCATION}"
	# prevent using untunneled internet
	prefixWith "[WINDSCRIBE]" echo "Enabling Windscribe firewall"
	prefixWith "[WINDSCRIBE]" windscribe firewall on


	### Binds SOCKS server using OpenSSH
	while true; do
		prefixWith "[SSH]" echo "Creating OpenSSH SOCKS server"
		prefixWith "[SSH]" ssh -4 -oStrictHostKeyChecking=accept-new -D 0.0.0.0:1080 -N root@127.0.0.1
		prefixWith "[SSH]" echo "SOCKS server died, restarting"
		sleep 1
	done

} 2>&1 1>&3 3>&- | { while read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') ERR $line"; done } } 3>&1 1>&2 | { while read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') OUT $line"; done }