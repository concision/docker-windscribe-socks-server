<h1 align="center">
    Dockerized Windscribe SOCKS5 Server
</h1>

<p align="center">
    <a href="https://github.com/concision/docker-windscribe-socks-server/blob/master/LICENSE">
        <img alt="repository license" src="https://img.shields.io/github/license/concision/docker-windscribe-socks-server?style=for-the-badge"/>
    </a>
    <a href="https://github.com/concision/docker-windscribe-socks-server/releases">
        <img alt="release version" src="https://img.shields.io/github/v/tag/concision/docker-windscribe-socks-server?style=for-the-badge&logo=git"/>
    </a>
    <a href="https://hub.docker.com/r/concisions/windscribe-socks-server">
        <img alt="Docker pulls" src="https://img.shields.io/docker/pulls/concisions/windscribe-socks-server?style=for-the-badge&logo=docker"/>
    </a>
</p>

<p align="center">
    <i>Containerizes a SOCKS5 proxy server with traffic tunneled through Windscribe's VPN service</i>
</p>

## Table of Contents
- [Motivations](#motivations)
- [Pro Et Contra](#pro-et-contra)
  - [Advantages](#advantages)
  - [Limitations](#limitations)
- [Deployment](#deployment)
  - [Image Source](#image-source)
  - [Deploying Container](#deploying-container)
    - [Docker Compose](#docker-compose)
    - [Docker CLI](#docker-cli)
  - [Configuration](#configuration)


## Motivations
[Windscribe](https://windscribe.com/) is a yet another VPN service, offering varying subscriptions plans (free, pro, "build a plan", etc). Typically, [Windscribe software](https://windscribe.com/download) must be installed on host devices to tunnel traffic through their VPN servers. However, there are [other protocols](https://windscribe.com/features/config-generators) (e.g. OpenVPN, IKEv2, SOCKS5, etc) supported for tunneling *without* their proprietary software. Unfortunately, these protocols are only available to users on their "Pro" subscription plan (i.e. excluding free and "Build A Plan" subscription plans).

I had submitted a feature request for SOCKS5 support for the "Build A Plan" option from their support, but have received a generic response indicating there was no particular interest in adding such support for non-"Pro" subscription plans. Ergo, Windscribe software must be installed on a host device to tunnel traffic, presenting two corollaries:
- a host device must be eligible for installing and running Windscribe VPN software
- _all_ system traffic will be tunneled through Windscribe servers

This project was created to address a fringe use-case and circumvent the aforementioned corollaries by containerizing Windscribe software within [Docker](https://www.docker.com/), enabling tunneling through as a SOCKS5 proxy server.


## Pro Et Contra
### Advantages
There are a few useful advantages of using this containerized application:
- Paid subscriptions are not required to use the SOCKS5 protocol to tunnel traffic through Windscribe.
- A host device does not need to install Windscribe system software and can still tunnel traffic through their VPN servers.
- Networking tools (e.g. [Proxifier](https://www.proxifier.com/)) can enable fine-grained control by handling per-process traffic tunneling, rather than system wide traffic tunneling.
 
### Limitations
However, there limitations to this project's usefulness relating significantly to security:
- Traffic to the SOCKS5 server is _not_ encrypted and may be interceptable by a third party; however, traffic forwarded to Windscribe is encrypted. 
- Without authentication, the SOCKS5 server should _only_ be used in a tightly controlled network. Exposing the SOCKS5 server publicly allows any actor to tunnel traffic that is linked back to the specified Windscribe account. As of version `0.3.0`, proxy server authentication can be configured through environment variables.
- [Windscribe-CLI](https://windscribe.com/guides/linux) requires `iptables` support, requiring the `NET_ADMIN` cap permission to execute inside of a Docker container. As a consequence, a compromised container may be able to leverage all the capabilities of `CAP_NET_ADMIN`, as defined in the [Linux manuals](http://man7.org/linux/man-pages/man7/capabilities.7.html). While it is unlikely the software involved would be compromised, there is a non-zero possibility that a compromised container may be able to manipulate the host's iptables for malicious purposes.


## Deployment
This project must be built using a container image building tool and run using container runtime (e.g. Docker, Podman, etc). [Docker](https://www.docker.com/) instructions are included in the following sections.

### Image Source
Pre-built images can be pulled from any of the following registries:
- [Docker Hub](https://hub.docker.com/r/concisions/windscribe-socks-server): `concisions/windscribe-socks-server:latest`
- [GitHub Packages](https://github.com/concision/docker-windscribe-socks-server/packages): `docker.pkg.github.com/concision/docker-windscribe-socks-server/windscribe-socks-server:latest`
> Note: The only prebuilt images architectures available are `linux/amd64` and `linux/arm/v7`. At the time of writing this documentation, Windscribe distributions are not available for other architectures.

Alternatively, the project can be built from the repository's sources by cloning the repository and running a container image build tool.
```bash
# clone the repository
git clone https://github.com/concision/docker-windscribe-socks-server.git
# change current working directory
cd docker-windscribe-socks-server
# build Docker image
docker build -t concisions/windscribe-socks-server:latest .
```
> Note: Ensure the current working directory is inside of the cloned Git repository prior to executing the command (e.g. `cd docker-windscribe-socks-server`).

### Deploying Container
#### Docker Compose
To deploy with [Docker Compose](https://docs.docker.com/compose/), use the commented configuration file available in this repository [here](https://github.com/concision/docker-windscribe-socks-server/blob/master/docker-compose.yml). Environment variables may be sourced with an `.env` file or explicitly defined in the configuration file.

The container can be deployed with the following command:
```bash
docker-compose up
```

#### Docker CLI
To deploy with [Docker](https://www.docker.com/), use the example run script available in this repository [here](https://github.com/concision/docker-windscribe-socks-server/blob/master/deploy-container.sh). It can be configured in the script itself or use an `.env` file.

The container can be deployed with the following command:
```bash
./deploy-container.sh
```
> Note: If specifying multiple SOCKS5 users, specify the relevant environment variables in an `.env` file or ads a `--env SOCKS_USERNAME_xyz` and `--env SOCKS_PASSWORD_xyz` flag (where "xyz" is a wildcard) to the script.

### Configuration
There are several environment variables that can be configured for this image:
- **Windscribe**:
  - `WINDSCRIBE_DNS` (optional): Whitespace delimited list of DNS servers to use (default: `1.1.1.1`). Setting a DNS server with Docker flags is not sufficient enough, as it utilizes an embedded local DNS server. Windscribe tunnels all DNS requests to prevent DNS leakage.
  - `WINDSCRIBE_USERNAME`: Windscribe account username.
  - `WINDSCRIBE_PASSWORD`: Windscribe account password.
  - `WINDSCRIBE_LOCATION` (optional): A preferred Windscribe location to automatically connect to.
- **SOCKS5 Server**:
  > Note: By default, there is no authentication enabled. Setting any of the environment variables `SOCKS_USERNAME` or `SOCKS_USERNAME_xyz` automatically enables authentication. Without authentication, the SOCKS5 server should _only_ be used in a tightly controlled network.
  - `SOCKS_USERNAME` (optional): Enables SOCKS5 authentication and creates a new user. Must be alphanumeric (with `_`s).
  - `SOCKS_PASSWORD` (optional): Enables SOCKS5 authentication and sets the password for the associated `$SOCKS_USERNAME` user.
  Additional users can be defined by namespacing (e.g. suffixing "_1") additional environment variables under pairs of `SOCKS_USERNAME` and `SOCKS_PASSWORD`:
  - `SOCKS_USERNAME_xyz` (optional): Enables SOCKS5 authentication and creates a new user. Must be alphanumeric (with `_`s).
  - `SOCKS_PASSWORD_xyz` (optional): Enables SOCKS5 authentication and sets the password for the associated `SOCKS_USERNAME_xyz` user.

## Disclaimer
This project is a prototype and has its own set of issues and drawbacks compared to running Windscribe system software. Your mileage may vary.
