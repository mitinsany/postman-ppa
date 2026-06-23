A PPA (unofficial) repository for Postman. Packages are small Debian wrappers that download the official versioned Postman Linux tarball during installation and install it under `/opt/Postman`.

# Usage

## Install via deb822 (.sources)

```bash
sudo curl -SsL -o /usr/share/keyrings/postman-ppa.gpg https://mitinsany.github.io/postman-ppa/postman-ppa.gpg
sudo curl -SsL -o /etc/apt/sources.list.d/postman-ppa-latest.sources https://mitinsany.github.io/postman-ppa/sources.list.d/postman-ppa-latest.sources
sudo apt update
sudo apt install postman
```

# Local build

```bash
docker build -f Dockerfile -t postman-ppa-builder .
docker run --rm -it -v "$PWD:/app" postman-ppa-builder bash -lc "./scripts/update-packages.sh"
```

# Sources

- https://www.postman.com/downloads/
- https://learning.postman.com/docs/getting-started/installation/install-app/
- https://mkt.cdn.postman.com/www-next/release-notes/app-release-notes.json

