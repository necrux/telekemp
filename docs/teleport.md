# Teleport

## Benefits

* Certs instead of keys:
  * Chain of trust.
  * known identity (non-repudiation).
  * short-lived and automatically revoked.
* Login secret management:
  * No more SSH key rotation.
  * No more static credentials (bots).
* Fully auditable:
  * Recorded sessions.
  * JIT access.

## Architecture

* Auth Service:
  * Maintains certificate authorities.
  * Stores cluster configurations.
  * Collects cluster data.
* Proxy Service
* Agents
  *  Sidecar-style daemons used to access service(s).

## Configuration

### Cluster Install (Single Instance)

```
VERSION=<VERSION>
EMAIL=<EMAIL>
DOMAIN=<DOMAIN>
LOGIN_USER=<USER>

curl https://cdn.teleport.dev/install.sh | bash -s ${VERSION}

teleport configure -o file \
  --acme \
  --acme-email=${EMAIL} \
  --cluster-name=${DOMAIN}

systemctl enable teleport
systemctl start teleport

# Add an admin user -- Visit invite URL to complete the user registration & configure MFA.
tctl users add teleport-admin --roles=editor,access --logins=${LOGIN_USER}
```

### Client

```
USER=<USER>
PROXY=<PROXY>

tsh logout
tsh login --user=${USER} --proxy=${PROXY}
```

## Thoughts

* Easy install.
* Easy to register clients.
* Cert creation is completely transparent.
* CLI is a first-class citizen.

## Look Into

* Install script on Ubuntu 26.04 (24.04 has no issues).
* Is there any way to switch clusters without logging out of the current one?

## Sources

* [Teleport: Repo](https://github.com/gravitational/teleport)
* [Teleport: Architecture](https://goteleport.com/docs/reference/architecture/)
* [Teleport: Install](https://goteleport.com/docs/installation/single-machine/linux/)
* [Teleport: Labs](https://goteleport.com/labs/)