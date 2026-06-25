<h1 align="center">Proxmox Backup Server<br />
<div align="center">
<a href="https://github.com/dockur/proxmox-backup/"><img src="https://github.com/dockur/proxmox-backup/raw/master/.github/logo.png" title="Logo" style="max-width:100%;" width="128" /></a>
</div>
<div align="center">

[![Build]][build_url]
[![Version]][tag_url]
[![Size]][tag_url]
[![Pulls]][hub_url]

</div></h1>

Proxmox Backup Server inside a Docker container.

## Features ✨

- **Incremental Backups** — Only the changes (deltas) made since the last backup are stored.
- **Global deduplication** — To save space identical data blocks are always stored only once.
- **Storage flexibility** — Offers a variety of storage options, including local storage, network-attached storage (NAS), and cloud-based storage.
- **Integrated with Proxmox VE** — Tight integration with [Proxmox VE](https://github.com/dockur/proxmox), allowing you to manage and schedule backups directly from the Proxmox web interface. 
- **Web interface and REST API** — Provides a web-based management interface that allows administrators to monitor backup jobs, configure schedules, and manage restore operations.

## Usage  🐳

##### Via Docker Compose:

```yaml
services:
  pbs:
    hostname: pbs
    container_name: pbs
    image: dockurr/proxmox-backup
    environment:
      PASSWORD: "root"
      TZ: "America/New_York"
    ports:
      - 8007:8007
    tmpfs:
      - /run
    volumes:
      - ./config:/etc/proxmox-backup
      - ./data:/var/lib/proxmox-backup
    restart: always
    stop_grace_period: 2m
```

##### Via Docker CLI:

```bash
docker run -it --rm --name pbs --hostname pbs -e "PASSWORD=root" -e "TZ=America/New_York" -p 8007:8007 --tmpfs /run -v "${PWD:-.}/config:/etc/proxmox-backup" -v "${PWD:-.}/data:/var/lib/proxmox-backup" --stop-timeout 120 docker.io/dockurr/proxmox-backup
```

##### Via Github Codespaces:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/dockur/proxmox-backup)

##  Screenshot 📸

<div align="center">
<a href="https://github.com/dockur/proxmox-backup"><img src="https://raw.githubusercontent.com/dockur/proxmox-backup/master/.github/screenshot.png" title="Screenshot" style="max-width:100%;" width="256" /></a>
</div>

## FAQ 💬

### How do I use it?

  Very simple! These are the steps:
  
  - Start the container and connect to [port 8007](http://127.0.0.1:8007/) using your web browser.

  - Login using the username `root` and the password you specified in the `PASSWORD` environment variable.
  
  Enjoy your time with your brand new Proxmox Backup Server, and don't forget to star this repo!

### How do I change the location of the configuration data?

  To change the location of the configuration data, include the following two bind mounts in your compose file:
  
  ```yaml
volumes:
  - ./config:/etc/proxmox-backup
  - ./data:/var/lib/proxmox-backup
  ```

  Replace the example paths `./config` and `./data` with the desired folders or named volumes.

### Are there containers available for other Proxmox products?

  Yes, see our [Proxmox VE](https://github.com/dockur/proxmox) and [Proxmox Datacenter Manager](https://github.com/dockur/proxmox-dm) containers.

## Acknowledgements 🙏

Special thanks to [feddar](https://github.com/feddar) and [wofferl](https://github.com/wofferl), this project would not exist without their invaluable work.

## Stars 🌟
[![Stargazers](https://raw.githubusercontent.com/star-stats/stars/refs/heads/data/charts/dockur-proxmox-backup.svg)](https://github.com/dockur/proxmox-backup/stargazers)

[build_url]: https://github.com/dockur/proxmox-backup/
[hub_url]: https://hub.docker.com/r/dockurr/proxmox-backup/
[tag_url]: https://hub.docker.com/r/dockurr/proxmox-backup/tags
[pkg_url]: https://github.com/dockur/proxmox-backup/pkgs/container/proxmox-backup

[Build]: https://github.com/dockur/proxmox-backup/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/dockurr/proxmox-backup/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/dockurr/proxmox-backup.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/dockurr/proxmox-backup/latest?arch=amd64&sort=semver&color=066da5
[Package]: https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fdockur%2Fproxmox-backup%2Fproxmox-backup.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls
