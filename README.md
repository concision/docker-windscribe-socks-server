# Windscribe SOCKS5 Server in Docker
[![version](https://img.shields.io/github/v/tag/concision/docker-windscribe-socks-server?color=blue&sort=semver)](https://github.com/concision/docker-windscribe-socks-server/releases)
[![docker pulls](https://img.shields.io/docker/pulls/concisions/windscribe-socks-server)](https://hub.docker.com/repository/docker/concisions/windscribe-socks-server)
[![license](https://img.shields.io/github/license/concision/docker-windscribe-socks-server)](https://github.com/concision/docker-windscribe-socks-server/blob/master/LICENSE)

## Motivations
[Windscribe](https://windscribe.com/) is a yet another VPN service, offering varying tiers of plans and subscriptions (free, pro, "build a plan", etc). Typically, traffic is tunneled through their servers by installing [Windscribe software](https://windscribe.com/download) on host devices. However, [additional methods](https://windscribe.com/features/config-generators) are available for tunneling without their software, through other protocols such as OpenVPN, IKEv2, and SOCKS5. Unfortunately, these protocols are unavailable to accounts that are not specifically on the "Pro" plan (e.g. free and "build a plan").

I had requested SOCKS5 support for the "Build A Plan" option from their support, but have received a generic response indicating that there was no particular interest in adding such support for any plans other than "Pro". As a result, Windscribe software must be utilized to tunnel traffic on a host device, presenting two corollaries:
- a host device must be able to install and run the Windscribe VPN software
- _all_ traffic is tunneled through Windscribe servers

This project addresses fringe use-cases and serves to avoid the aforementioned corollaries by containerizing Windscribe software in [Docker](https://www.docker.com/) and exposing a tunnel as a SOCKS5 proxy server.


## Pro Et Contra
### Benefits
There are a few benefits of using this project's containerized application:
- No premium subscription is necessary to use the SOCKS5 protocol to tunnel traffic through Windscribe.
- A host device incompatible with Windscribe software can still leverage tunneling through their VPN.
- Traffic on a host device may be finely controlled to only tunnel specific traffic through Windscribe.
    - Not all traffic may need to be tunneled, and tunneled traffic may incur a significant bandwidth and latency performance hit.
    - Tools such as [Proxifier](https://www.proxifier.com/) may be utilized to handle per-process traffic tunneling.
    - Some internet services have blacklisted commonly used Windscribe IP ranges, previously presenting an issue accessing specific services when the VPN was connected. 
- Containerization allows tunneling traffic through Windscribe in Docker stacks.
 
### Limitations
There are, however, limitations to this project's usefulness relating significantly to security:
- The SOCKS5 server has no authentication - the SOCKS5 server should _only_ be used in a tightly controlled network.
    - Exposing the SOCKS5 server publicly allows any individual to tunnel traffic that is ultimately linked to a specific Windscribe account.
    > Note: This concern can be addressed by swapping the underlying implementation of the SOCKS5 to an proxy server that supports authentication (e.g. [dante](https://www.inet.no/dante/)).
- [Windscribe-CLI](https://windscribe.com/guides/linux) requires iptables support, requiring the NET_ADMIN cap permission to execute inside of a Docker container. As a corollary, a compromised container may be able to leverage all the capabilities of CAP_NET_ADMIN, as defined in the [Linux manuals](http://man7.org/linux/man-pages/man7/capabilities.7.html).
    - While it is unlikely the software involved would be compromised, there is a non-zero possibility that a compromised container may be able to manipulate the host's iptables for malicious reasons.


## Deployment
This project is bundled into a Docker image, making [Docker](https://www.docker.com/) a prerequisite for running this project.

### Source
A pre-built image is available for pulling from any of the following registries:
- [Docker Hub](https://hub.docker.com/r/concisions/windscribe-socks-server)
- [GitHub Packages](https://github.com/concision/docker-windscribe-socks-server/packages)

The only currently supported OS/arch is linux/amd64.

Alternatively, the project can be built from the Dockerfile for new architectures by executing the following command in the project root directory:
```bash
docker build -t concisions/windscribe-socks-server:latest .
```

### Configuration
There are several environment variables that can be configured for this image:
- `WINDSCRIBE_DNS` (optional): Whitespace delimited list of DNS servers to use (default: `1.1.1.1`). Setting a DNS server with Docker flags is not sufficient enough, as it utilizes an embedded local DNS server. Windscribe tunnels all DNS requests to prevent DNS leakage.
- `WINDSCRIBE_USERNAME`: Windscribe account username.
- `WINDSCRIBE_PASSWORD`: Windscribe account password.
- `WINDSCRIBE_LOCATION` (optional): A preferred Windscribe location to automatically connect to.

### Docker Compose
To deploy with Docker compose, a commented configuration file is available in this repository [here](https://github.com/concision/docker-windscribe-socks-server/blob/master/docker-compose.yml). Environment variables may be sourced with an `.env` file or explicitly defined in the configuration file.

To deploy it, the following command can be executed:
```bash
docker-compose up
```

### Docker CLI
To deploy with only Docker, an example run script is available in this repository [here](https://github.com/concision/docker-windscribe-socks-server/blob/master/deploy-container.sh). It can be configured in the script itself or use an `.env` file.

To deploy it, the following command can be executed:
```bash
./deploy-container.sh
```
> Note: Running the container interactively may break Windscribe authentication