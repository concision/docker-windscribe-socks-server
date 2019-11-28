FROM ubuntu:latest

# expose SOCKS server port
EXPOSE 1080/tcp

# install Windscribe and OpenSSH server
RUN \
    # obtain caches
    apt-get update && \
    # install dependencies
    apt-get install -y \
        # apt-key
        gnupg2 \
        # verify Windscribe repository
        ca-certificates \
        # fix Windscribe's resolveconf linux dependency
        apt-utils debconf-utils dialog \
        # required for Windscribe
        iptables \
        # sanitize Windows \r\n formatting
        dos2unix \
        # openssh to create a SOCKS server
        openssh-server \
        && \
    # fix resolveconf dependency configuration (as per https://stackoverflow.com/a/51507868)
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections && \
    # add Windscribe signing key
    apt-key adv --keyserver keyserver.ubuntu.com --recv-key FDC247B7 && \
    # add Windscribe repository
    echo 'deb https://repo.windscribe.com/ubuntu zesty main' | tee /etc/apt/sources.list.d/windscribe-repo.list && \
    # install Windscribe
    apt-get update && \
    apt-get install -y windscribe-cli && \
    # clean cache
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# disable SSH shell
RUN chsh --shell /bin/false

# add entrypoint
COPY docker-entrypoint.sh /

# mark as executable
RUN dos2unix /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
