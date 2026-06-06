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

- **Incremental Backups** — After an initial full backup, PBS performs incremental backups, where only changes (deltas) made since the last backup are stored.
- **Global deduplication** — This means that all identical data blocks are stored only once.
- **Efficient restores** — You can restore entire VMs, containers, or even specific files from backups.
- **Storage flexibility** — Offers a variety of storage options, including local storage, network-attached storage (NAS), and cloud-based storage.
- **Backup and restore from Proxmox VE** — Tight integration with Proxmox VE, allowing you to manage and schedule backups directly from the Proxmox web interface. 
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
    volumes:
      - ./config:/etc/proxmox-backup
      - ./logs:/var/log/proxmox-backup
      - ./data:/var/lib/proxmox-backup
    tmpfs:
      - /run
    cap_add:
      - SYS_RAWIO
    restart: always
    stop_grace_period: 2m
```

##### Via Docker CLI:

```bash
docker run -it --rm --name proxmox --hostname pve --privileged -e "PASSWORD=root" -p 8006:8006 -v "${PWD:-.}/storage:/var/lib/vz" -v "${PWD:-.}/config:/var/lib/pve-cluster" --stop-timeout 120 docker.io/dockurr/proxmox
```

##### Via Github Codespaces:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/dockur/proxmox-backup)

## Requirements 🛠️

- Intel VT-x / AMD-V enabled
- Modern Linux host with kernel 6.8+
- [Docker Engine](https://docs.docker.com/engine/install/) (version 27+ recommended)
- Windows 11 with Docker Desktop (WSL2):
   - WSL kernel version 6.6+ (`wsl --version`)
   - Nested virtualization enabled in WSL Settings

## Screenshot 📸

<div align="center">
<a href="https://github.com/dockur/proxmox-backup"><img src="https://raw.githubusercontent.com/dockur/proxmox-backup/master/.github/screenshot.png" title="Screenshot" style="max-width:100%;" width="256" /></a>
</div>

## FAQ 💬

### How do I use it?

  Very simple! These are the steps:
  
  - Start the container and connect to [port 8006](http://127.0.0.1:8006/) using your web browser.

  - Login using the username `root` and the password you specified in the `PASSWORD` environment variable.
  
  Enjoy your time with your brand new Proxmox installation, and don't forget to star this repo!

### How do I change the location of the storage pool?

  To change the location for the `local` storage pool used by Proxmox to store large objects like disk images and .iso files, include the following bind mount in your compose file:

  ```yaml
  volumes:
    - ./storage:/var/lib/vz
  ```

  Replace the example path `./storage` with the desired storage folder or named volume.

### How do I change the location of the configuration data?

  To change the location of your Proxmox VE configuration data, include the following bind mount in your compose file:
  
  ```yaml
  volumes:
    - ./config:/var/lib/pve-cluster
  ```

  Replace the example path `./config` with the desired storage folder or named volume.

### How do I verify if my system supports the KVM virtualization used by Proxmox?

  First check if your software is compatible using this chart:

  | **Product**  | **Linux** | **Win11** | **Win10** | **macOS** |
  |---|---|---|---|---|
  | Docker CLI        | ✅   | ✅       | ❌        | ❌ |
  | Docker Desktop    | ❌   | ✅       | ❌        | ❌ | 
  | Podman CLI        | ✅   | ✅       | ❌        | ❌ | 
  | Podman Desktop    | ✅   | ✅       | ❌        | ❌ | 

  After that you can run the following commands in Linux to check your system:

  ```bash
  sudo apt install cpu-checker
  sudo kvm-ok
  ```

  If you receive an error from `kvm-ok` indicating that KVM cannot be used, please check whether:

  - the virtualization extensions (`Intel VT-x` or `AMD SVM`) are enabled in your BIOS.

  - you enabled "nested virtualization" if you are running the container inside a virtual machine.

  - you are not using a cloud provider, as most of them do not allow nested virtualization for their VPS's.

## Acknowledgements 🙏

Special thanks to [LongQT-sea](https://github.com/LongQT-sea), this project would not exist without his invaluable work.

## Stars 🌟
[![Stars](https://starchart.cc/dockur/proxmox-backup.svg?variant=adaptive)](https://starchart.cc/dockur/proxmox-backup)

[build_url]: https://github.com/dockur/proxmox-backup/
[hub_url]: https://hub.docker.com/r/dockurr/proxmox-backup/
[tag_url]: https://hub.docker.com/r/dockurr/proxmox-backup/tags
[pkg_url]: https://github.com/dockur/proxmox-backup/pkgs/container/proxmox-backup

[Build]: https://github.com/dockur/proxmox-backup/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/dockurr/proxmox-backup/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/dockurr/proxmox-backup.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/dockurr/proxmox-backup/latest?arch=amd64&sort=semver&color=066da5
[Package]: https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fdockur%2Fproxmox-backup%2Fproxmox-backup.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls
