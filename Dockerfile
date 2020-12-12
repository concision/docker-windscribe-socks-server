### Ubuntu 18
# Same version as built image to minimize pulls
FROM ubuntu:bionic-20200921 AS sources

## Linux Depenedencies
# install dos2unix to sanitize dotenv CRLF line endings
RUN apt-get update && apt-get install -y dos2unix

## Project Sources
# copy scripts
COPY src/docker-entrypoint.sh src/docker-healthcheck.sh lib/dotenv/dotenv /wss/home/wss/
# ensure scripts are executable
RUN dos2unix /wss/home/wss/* && chmod +x /wss/home/wss/*

# copy Danted Configuration
COPY src/config/danted.conf /wss/etc/danted.conf


### Ubuntu 18
# Using ubuntu 18, as there appears to be compatiblity issues with later ubuntu versions on linux/arm/v7.
# See https://bugs.launchpad.net/cloud-images/+bug/1896443
FROM ubuntu:bionic-20200921

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
    echo 'deb https://repo.windscribe.com/ubuntu bionic main' | tee /etc/apt/sources.list.d/windscribe-repo.list && \
    # update repository
    apt-get update && \
    # install Windscribe
    apt-get install -y windscribe-cli && \
    # remove Windscribe repository key
    apt-key del FDC247B7 && \
    # remove packages
    apt-get purge -y gnupg2 apt-utils debconf-utils apt-utils debconf-utils dialog && apt-get autoremove -y && \
    # remove Windscribe repository file
    rm -rf /etc/apt/sources.list.d/windscribe-repo.list && \
    # cleanup apt-get lists
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # clear logs
    rm -rf /var/log/*

### Project Layer
COPY --from=sources /wss /

## Metadata
# maintainer tag
LABEL maintainer="contact@concision.me"

## Configure Image
# expose SOCKS5 server port
EXPOSE 1080/tcp
# default entrypoint command
CMD ["/home/wss/docker-entrypoint.sh"]
# default docker healthcheck
HEALTHCHECK --interval=120s --timeout=30s --start-period=15s --retries=3 \
        CMD "/home/wss/docker-healthcheck.sh"
