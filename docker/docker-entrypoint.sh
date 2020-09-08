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

### Execute script with timestamp logging
{ {
    ### Sanity Checks
    # Ensure shell is non-interactive
    if [ -t 0 ] ; then
        echo "Container cannot be run interactively" 1>&2
        exit 1
    fi

    # iptable support checks
    iptables -vnL > /dev/null 2>&1 || {
        prefixWith "[IPTABLES]" echo "Ensure cap_add is set to NET_ADMIN" 1>&2
        exit 1
    }

    # username checks
    if [[ -z "${WINDSCRIBE_USERNAME}" ]]; then
        prefixWith "[WINDSCRIBE]" echo "Unset Windscribe username; ensure that the environment variable \$WINDSCRIBE_USERNAME is set properly" 1>&2
        exit 1
    fi
    if [[ "${WINDSCRIBE_USERNAME}" =~ [^a-zA-Z0-9_] ]]; then
        prefixWith "[WINDSCRIBE]" echo "Windscribe username must be alphanumeric (underscores allowed); ensure that the environment variable \$WINDSCRIBE_USERNAME is set properly" 1>&2
        exit 1
    fi
    # validate password checks
    if [[ -z "${WINDSCRIBE_PASSWORD}" ]]; then
        prefixWith "[WINDSCRIBE]" echo "Unset Windscribe password; ensure that the environment variable \$WINDSCRIBE_PASSWORD is set properly" 1>&2
        exit 1
    fi
    # ensure no newlines present (source: https://unix.stackexchange.com/a/276836)
    NL='
    '
    case "${WINDSCRIBE_PASSWORD}" in *"${NL}"*) prefixWith "[WINDSCRIBE]" echo "Windscribe password cannot contain new lines; ensure that the environment variable \$WINDSCRIBE_PASSWORD is set properly" 1>&2
        exit 1;;
    esac
    # validate windscribe location
    # ensure no newlines present
    case "${WINDSCRIBE_LOCATION}" in *"${NL}"*) prefixWith "[WINDSCRIBE]" echo "Windscribe location cannot contain new lines; ensure that the environment variable \$WINDSCRIBE_LOCATION is set properly" 1>&2
        exit 1;;
    esac

    # indicates that proxy server authentication is enabled
    authentication=false
    prefixWith "[SOCKS5]" echo "Searching for SOCKS_USERNAME and SOCKS_PASSWORD environment variables"
    # search and register proxy server accounts
    for socks_username in $(printenv | grep "^SOCKS_USERNAME"); do
        # strip SOCKS_USERNAME prefix
        VAR=$(echo ${socks_username} | sed --expression='s/^SOCKS_USERNAME//')
        # read "SOCKS_USERNAME$suffix=$username" format
        IFS='=' read -r suffix username <<< "${VAR}"

        # build variable as string
        password_env="SOCKS_PASSWORD$suffix"
        # dereference variable
        password="${!password_env}"

        # validate username and password
        if [[ "${username}" ]]; then
            if [[ "${username}" =~ [^a-zA-Z0-9_] ]]; then
                prefixWith "[SOCKS5]" echo "Detected user environment variable from \$SOCKS_USERNAME${suffix}, but the value was not alphanumeric (with _); username: ${username}" 1>&2
                exit 1
            fi
            if [[ "${password}" ]]; then
                prefixWith "[SOCKS5]" echo "Detected user environment variable from \$SOCKS_USERNAME${suffix} (username: ${username}); creating account"
            else
                prefixWith "[SOCKS5]" echo "Detected user environment variable from \$SOCKS_USERNAME${suffix}, but no password was specified at \$SOCKS_PASSWORD${suffix}; username: ${username}" 1>&2
                exit 1
            fi
        else
            prefixWith "[SOCKS5]" echo "Detected user environment variable from \$SOCKS_USERNAME${suffix}, but the value was empty; ignoring entry" 1>&2
            continue
        fi

        # ensure no duplicate account names
        if id "${username}" &>/dev/null; then
            prefixWith "[SOCKS5]" echo "The requested username (from \$SOCKS_USERNAME${suffix}) is either reserved or already allocated, ignoring; username: ${username}" 1>&2
            continue
        fi

        # create user account
        useradd -s /sbin/nologin "${username}"
        yes "${password}" | passwd "${username}" 2>/dev/null

        # mark authentication as enabled
        authentication=true
    done
    if [ "${authentication}" = false ]; then
        prefixWith "[SOCKS5]" echo "No non-empty SOCKS5 accounts were received (check that the environment variables are set correctly)"
    fi

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
        prefixWith "[WINDSCRIBE]" echo "No \$WINDSCRIBE_LOCATION was specified; available Windscribe locations:"
        windscribe locations
    fi
    prefixWith "[WINDSCRIBE]" windscribe connect "${WINDSCRIBE_LOCATION}"
    # prevent using untunneled internet
    prefixWith "[WINDSCRIBE]" echo "Enabling Windscribe firewall"
    prefixWith "[WINDSCRIBE]" windscribe firewall on


    ### Fix eth0 networking
    # get eth0 interface IP (see https://unix.stackexchange.com/a/8521)
    INTERFACE_IP=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
    # get eth0 default gateway (see https://stackoverflow.com/a/1226395)
    GATEWAY_IP=$(ip route | awk '/default/ { print $3 }')

    # reply to packets on same interface as received (see https://unix.stackexchange.com/a/23345)
    echo 200 isp2 >> /etc/iproute2/rt_tables
    ip rule add from "${INTERFACE_IP}" table isp2
    ip route add default via "${GATEWAY_IP}" table isp2


    ### Binds SOCKS server using Dante
    prefixWith "[DANTE]" echo "Generating configuration file"
    # replace ${SOCKS_METHOD} in dante configuration with the authentication mode
    sed -i "s/\${SOCKS_METHOD}/$([ "${authentication}" = true ] && echo username || echo none)/" /etc/danted.conf

    prefixWith "[DANTE]" echo "Starting Danted server"
    prefixWith "[DANTE]" danted

} 2>&1 1>&3 3>&- | { while read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') ERR $line"; done } } 3>&1 1>&2 | { while read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') OUT $line"; done }
