### Sanitize Windows \r\n formatting for Unix scripts
FROM alpine as sanitized

## Dependencies
RUN apk --no-cache add dos2unix

## Scripts
COPY docker-entrypoint.sh docker-healthcheck.sh /scripts/
# sanitize scripts
RUN dos2unix /scripts/*.sh && \
    chmod +x /scripts/*.sh

## Danted Configuration
COPY config/danted.conf /etc/danted.conf
# sanitize configuration
RUN dos2unix /etc/danted.conf


### Image Configuration
FROM ubuntu

# expose SOCKS server port
EXPOSE 1080/tcp

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

## Add Docker scripts and configuration
# add scripts
COPY --from=sanitized /scripts /
# add dante server configuration
COPY --from=sanitized /etc/danted.conf /etc/danted.conf

## Configure Image
# default command
CMD ["/docker-entrypoint.sh"]
# healthcheck
HEALTHCHECK --interval=120s --timeout=30s --start-period=15s --retries=3 \
            CMD "/docker-healthcheck.sh"
