### Ubuntu 20
FROM ubuntu:groovy-20200812

## Configure Image
# expose SOCKS5 server port
EXPOSE 1080/tcp
# default entrypoint command
CMD ["/docker-entrypoint.sh"]
# docker healthcheck
HEALTHCHECK --interval=120s --timeout=30s --start-period=15s --retries=3 \
        CMD "/docker-healthcheck.sh"

## Linux Dependencies
# install Windscribe and Dante server
RUN \
    # update package listings
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
        # IP healthcheck
        curl \
        # danted proxy server
        dante-server && \
    # fix resolveconf dependency configuration (as per https://stackoverflow.com/a/51507868)
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections && \
    # add Windscribe signing key
    apt-key adv --keyserver keyserver.ubuntu.com --recv-key FDC247B7 && \
    # add Windscribe repository
    echo 'deb https://repo.windscribe.com/ubuntu zesty main' | tee /etc/apt/sources.list.d/windscribe-repo.list && \
    # update repository
    apt-get update && \
    # install Windscribe
    apt-get install -y windscribe-cli && \
    # remove Windscribe repository key
    apt-key del FDC247B7 && \
    # cleanup apt-get lists
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # clear logs
    rm -rf /var/logs/*

## Project Sources
# copy scripts
COPY docker/docker-entrypoint.sh docker/docker-healthcheck.sh /
# ensure scripts are executable
RUN chmod +x /docker-entrypoint.sh /docker-healthcheck.sh

# copy Danted Configuration
COPY docker/config/danted.conf /etc/danted.conf
