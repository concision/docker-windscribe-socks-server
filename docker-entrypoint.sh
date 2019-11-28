#!/bin/bash

set -e

### Formatting
# time formatting
exec 2> >(while read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') ERR $line"; done) \
      > >(while read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') OUT $line"; done)

# command prefixing (source: https://unix.stackexchange.com/a/440514)
prefixWith() {
    local prefix="$1"
    shift

    # redirect standard input and error to different commands (source: https://stackoverflow.com/a/31151808)
    { "$@" 2>&1 1>&3 3>&- | { while read -r line; do  echo "$prefix $line"; done; }; } 3>&1 1>&2 | { while read -r line; do  echo "$prefix $line"; done; }
}


### Sanity Checks
if [[ -z "${WINDSCRIBE_USERNAME}" ]]; then
  	prefixWith "[WINDSCRIBE]" echo "Unset Windscribe username; ensure that the environment variable \$WINDSCRIBE_USERNAME is set "
	  exit 1
fi
if [[ -z "${WINDSCRIBE_PASSWORD}" ]]; then
  	prefixWith "[WINDSCRIBE]" echo "Unset Windscribe password; ensure that the environment variable \$WINDSCRIBE_PASSWORD is set "
	  exit 1
fi
iptables -vnL > /dev/null 2>&1 || {
    prefixWith "[IPTABLES]" echo "Ensure cap_add is set for both NET_RAW and NET_ADMIN"
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
prefixWith "[TUN]" echo "Creating TUN device"
prefixWith "[TUN]" mkdir -p /dev/net
prefixWith "[TUN]" mknod /dev/net/tun c 10 200
prefixWith "[TUN]" chmod 600 /dev/net/tun


### Start Windscribe client
# Windscribe performs DNS lookups remotely using locally configured DNS nameservers; use Googles
echo "nameserver 8.8.8.8" > /etc/resolv.conf
# start windscribe daemon
prefixWith "[WINDSCRIBE]" echo "Starting Windscribe client"
prefixWith "[WINDSCRIBE]" windscribe start
# authenticate to Windscribe
prefixWith "[WINDSCRIBE]" echo "Authenticating to Windscribe"
windscribe login <<- EOF
${WINDSCRIBE_USERNAME}
${WINDSCRIBE_PASSWORD}
EOF
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
