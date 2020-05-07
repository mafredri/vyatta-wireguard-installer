# vyatta-wireguard-installer

Install, upgrade or remove WireGuard ([WireGuard/wireguard-vyatta-ubnt](https://github.com/WireGuard/wireguard-vyatta-ubnt)) on Ubiquiti hardware. By default, the installer caches the deb-package so that the same version of WireGuard can be restored after a firmware upgrade.

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
Install, upgrade or remove WireGuard (github.com/WireGuard/wireguard-vyatta-ubnt) on
Ubiquiti hardware. By default, the installer caches the deb-package so that the
same version of WireGuard can be restored after a firmware upgrade.

Note: This script can be placed in /config/scripts/post-config.d for automatic
installation after firmware upgrades.

Usage:
  ./wireguard.sh [COMMAND] [OPTION]...

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

## Configuration

### Automatic upgrade

The script in this repo can be used to perform automatic upgrades via the VyOS task scheduler. See [VyOS Wiki: Task scheduler](https://wiki.vyos.net/wiki/Task_scheduler) for more configuration options.

**WARNING:** There is no rollback functionality implemented (yet). If something goes wrong during the auto upgrade you could be left with a non-functioning WireGuard install.

#### On device configuration

This configuration method can be used on any Ubiquti device, but will not persist across provisions on the USG.

```console
configure
set system task-scheduler task wireguard_auto_upgrade executable path /config/scripts/post-config.d/wireguard.sh
set system task-scheduler task wireguard_auto_upgrade executable arguments upgrade
set system task-scheduler task wireguard_auto_upgrade interval 14d
commit
save
exit
```

#### Ubiquiti Security Gateway

Update your `config.gateway.json` to include the following:

```json
{
	"system": {
		"task-scheduler": {
			"task": {
				"wireguard_auto_upgrade": {
					"executable": {
						"path": "/config/scripts/post-config.d/wireguard.sh",
						"arguments": "upgrade"
					},
					"interval": "14d"
				}
			}
		}
	}
}
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
- [VyOS Wiki: Task scheduler](https://wiki.vyos.net/wiki/Task_scheduler)
- [Lochnair/vyatta-wireguard#62: feature request: make wireguard sustain firmware updates](https://github.com/Lochnair/vyatta-wireguard/issues/62)
