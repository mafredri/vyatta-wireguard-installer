# vyatta-wireguard-installer

Install, upgrade or remove WireGuard ([Lochnair/vyatta-wireguard](https://github.com/Lochnair/vyatta-wireguard)) on Ubiquiti hardware. By default, the installer caches the deb-package so that the same version of WireGuard can be restored after a firmware upgrade.

## Installation

Simply copy the script onto your Ubiquiti router and run it.

**Note:** By placing this script in `/config/scripts/post-config.d`, the WireGuard installation will persist across firmware upgrades.

```console
curl -sSL https://github.com/mafredri/vyatta-wireguard-installer/raw/master/wireguard.sh -o /config/scripts/post-config.d/wireguard.sh
chmod +x /config/scripts/post-config.d/wireguard.sh
```

## Usage

```console
$ ./wireguard.sh help
Install, upgrade or remove WireGuard (github.com/FossoresLP/vyatta-wireguard) on
Ubiquiti hardware. By default, the installer caches the deb-package so that the
same version of WireGuard can be restored after a firmware upgrade.

Note: This script can be placed in /config/scripts/post-config.d for automatic
installation after firmware upgrades.

Usage:
  $0 [COMMAND] [OPTION]...

Commands:
  check        Check if there's a new version of WireGuard (without installing)
  install      Install the latest version of WireGuard
  upgrade      Upgrade WireGuard to the latest version
  remove       Remove WireGuard
  self-update  Fetch the latest version of this script
  help         Show this help
  version      Show the version of this tool

Options:
      --no-cache  Disable package caching, cache is used during (re)install
```

## Todo

- Investigate using `/config/scripts/pre-config.d` for post-firmware upgrade installation
  - Why? It would make WireGuard available by the time the initial configuration is run
  - Possible, since we cache the installer in `/config/user-data/wireguard/cache`.
- Periodically check for new releases via cron (+automatic upgrades)
- Support rollback if a release doesn't work as expected?
- Check compatibility with current kernel / firmware version?

## Resources

- [VyOS Wiki: Configuration management](https://wiki.vyos.net/wiki/Configuration_management)
- [Lochnair/vyatta-wireguard#62: feature request: make wireguard sustain firmware updates](https://github.com/Lochnair/vyatta-wireguard/issues/62)
