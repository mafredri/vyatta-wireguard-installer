#!/bin/bash
if [ "$(id -g -n)" != 'vyattacfg' ] ; then
    exec sg vyattacfg -c "/bin/bash $(readlink -f $0) $@"
fi
set -e

# The repository from which we fetch new releases.
WIREGUARD_REPO=WireGuard/wireguard-vyatta-ubnt

WIREGUARD_INSTALLER_VERSION=1.2.0

declare -A SUPPORTED_BOARDS
SUPPORTED_BOARDS=(
	[e50]=e50 # ER-X (EdgeRouter X)
	[e51]=e50 # ER-X-SFP (Edgerouter X SFP)
	[e101]=e100 # ERLite-3 (EdgeRouter Lite 3-Port)
	[e102]=e100 # ERPoe-5 (EdgeRouter PoE 5-Port)
	[e200]=e200 # EdgeRouter Pro 8-Port
	[e201]=e200 # EdgeRouter 8-Port
	[e300]=e300 # ER-4 (EdgeRouter 4)
	[e301]=e300 # ER-6P (EdgeRouter 6P)
	[e302]=e300 # ER-12 (EdgeRouter 12/12P)
	[e1000]=e1000 # USG-XG (EdgeRouter Infinity)
	[e120]=ugw3 # UGW3 (UniFi-Gateway-3)
	[e221]=ugw4 # UGW4 (UniFi-Gateway-4)
	[e1020]=ugwxg # USG-XG (UniFi Security Gateway XG)
)

WIREGUARD_DIR=/config/user-data/wireguard
CACHE_DIR=$WIREGUARD_DIR/cache
LATEST_FILE=$CACHE_DIR/latest

config() {
	/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper "$@"
}

current_version() {
	dpkg-query --showformat=\$\{Version\} --show wireguard 2>/dev/null
}

deb_version() {
	dpkg-deb --showformat=\$\{Version\} --show "$1"
}

is_installed() {
	current_version >/dev/null
}

latest_release_for() {
	local board=$1

	# Fetch the latest release, sorted by created_at attribute since this is
	# how GitHub operates for the /releases/latest end-point. We would use
	# it, but it does not contain pre-releases.
	#
	# From the GitHub API documentation:
	# > The created_at attribute is the date of the commit used for the
	# > release, and not the date when the release was drafted or published.
	curl -sSL https://api.github.com/repos/${WIREGUARD_REPO}/releases \
		| jq -r --arg version "${board}" \
			'sort_by(.created_at) | reverse | .[0] | .tag_name as $tag_name
			| .assets | map(select(.name | contains($version)))
			| {name: .[0].name, url: .[0].browser_download_url, tag: $tag_name}'
}

disable_wireguard() {
	local -a interfaces
	IFS=" " read -r -a interfaces <<<"$(wg show interfaces)"

	config begin
	# Disable routing on all interfaces so that we can delete the
	# wireguard interface.
	for i in "${interfaces[@]}"; do
		echo "Disabling ${i}..."
		config set interfaces wireguard "$i" route-allowed-ips false
	done
	config commit
	config delete interfaces wireguard
	config commit
	config end

	echo "Unloading kernel module..."
	sudo modprobe -r wireguard
}

reload_config() {
	echo "Reloading configuration..."
	config begin
	config load
	config commit
	config end
}

install() {
	local name package

	if [[ $* =~ --no-cache ]] || ! [[ -f $LATEST_FILE ]]; then
		upgrade "$@"
		return $?
	fi

	name=$(<$LATEST_FILE)
	package=$CACHE_DIR/$name

	echo "Installing ${name}..."
	sudo dpkg -i "$package"
	sudo modprobe wireguard

	sudo mkdir -p $WIREGUARD_DIR
	sudo chmod g+w $WIREGUARD_DIR
	echo "$name" >$WIREGUARD_DIR/installed

	reload_config
}

upgrade() {
	local asset_data name url package version update_cache=1 skip_install=0

	if [[ $* =~ --no-cache ]]; then
		update_cache=0
	fi

	echo "Checking latest release for ${BOARD}..."
	asset_data=$(latest_release_for "$BOARD")
	name=$(jq -r .name <<<"$asset_data")
	url=$(jq -r .url <<<"$asset_data")
	version=$(jq -r .tag <<<"$asset_data")
	package=/tmp/$name

	if [[ $version == $(current_version) ]]; then
		# Avoid exiting if the cache is missing and we should update it.
		if ((update_cache)) && ! [[ -f $LATEST_FILE ]]; then
			echo "WireGuard is already up to date ($(current_version)) but the cache is missing, continuing."
			skip_install=1
		else
			echo "WireGuard is already up to date ($(current_version)), nothing to do."
			exit 1
		fi
	fi

	echo "Downloading ${name}..."
	curl -sSL "$url" -o "$package"

	if ((skip_install)); then
		echo "Skipping installation..."
	else
		if is_installed; then
			# Delay until _after_ we have successfully
			# downloaded the latest release.
			disable_wireguard
		fi

		echo "Installing ${name}..."
		sudo dpkg -i "$package"
		sudo modprobe wireguard
	fi

	sudo mkdir -p $WIREGUARD_DIR
	sudo chmod g+w $WIREGUARD_DIR
	echo "$name" >$WIREGUARD_DIR/installed

	if ((update_cache)); then
		# Ensure cache directory exists.
		sudo mkdir -p $CACHE_DIR
		sudo chmod g+w $CACHE_DIR

		echo "Purging previous cache..."
		rm -fv $CACHE_DIR/*.deb
		echo "Caching installer to ${CACHE_DIR}..."
		cp -v "$package" $CACHE_DIR/"$name"

		echo "$name" >$LATEST_FILE
	fi

	rm -f "$package"

	if ((!skip_install)); then
		reload_config
	fi
}

run_check() {
	local asset_data name url version

	asset_data=$(latest_release_for "$BOARD")
	name=$(jq -r .name <<<"$asset_data")
	url=$(jq -r .url <<<"$asset_data")
	version=$(jq -r .tag <<<"$asset_data")

	if is_installed; then
		if [[ $version == $(current_version) ]]; then
			echo "WireGuard is up to date ($(current_version))."
		else
			echo "There is a new WireGuard version available!"
			echo "New version:       ${version}"
			echo "Installed version: $(current_version)"
		fi
	else
		echo "Latest version of WireGuard: ${version}"
	fi
}

run_install() {
	if is_installed; then
		echo "WireGuard is already installed ($(current_version)), nothing to do."
		exit 0
	fi

	echo "Installing WireGuard..."
	install "$@"
	echo "Install complete!"
}

run_upgrade() {
	if ! is_installed; then
		echo "WireGuard is not installed, please run install first."
		exit 1
	fi

	echo "Upgrading WireGuard..."
	upgrade "$@"
	echo "Upgrade complete!"
}

run_remove() {
	if ! is_installed; then
		echo "WireGuard is not installed, nothing to do."
		exit 0
	fi

	echo "Removing WireGuard..."

	disable_wireguard

	# Prevent automatic installation.
	rm -f $WIREGUARD_DIR/installed

	echo "Purging package..."
	sudo dpkg --purge wireguard

	echo "WireGuard removed!"
}

run_self_update() {
	tmpdir=$(mktemp -d)
	cat <<-EOS >"$tmpdir"/wireguard-script-self-update.sh
		#!/bin/bash
		set -e

		OLD_SCRIPT="${BASH_SOURCE[0]}"
		NEW_SCRIPT="$tmpdir"/wireguard-latest.sh

		echo "Downloading script..."
		curl -sSL https://github.com/mafredri/vyatta-wireguard-installer/raw/master/wireguard.sh -o \$NEW_SCRIPT

		echo "Checking for changes..."
		echo
		if ! diff -u "\$OLD_SCRIPT" "\$NEW_SCRIPT"; then
			echo
			read -p "Use updated script (Y/n)? " update
			if [[ -z \$update ]] || [[ \$update =~ [yY] ]]; then
				cat "\$NEW_SCRIPT" >"\$OLD_SCRIPT"
				echo "Script updated!"
			else
				echo "Aborting update..."
			fi
		else
			echo "Script is already up to date, nothing to do."
		fi
		rm -rfv "${tmpdir}"
		exit 0
	EOS

	chmod +x "$tmpdir"/wireguard-script-self-update.sh
	exec "$tmpdir"/wireguard-script-self-update.sh
}

usage() {
	cat <<EOU 1>&2
Install, upgrade or remove WireGuard (github.com/${WIREGUARD_REPO}) on
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

EOU
}

BOARD_ID="$(/usr/sbin/ubnt-hal-e getBoardIdE)"
BOARD=${SUPPORTED_BOARDS[$BOARD_ID]}

if [[ -z $BOARD ]]; then
	echo "Unsupported board ${BOARD_ID}, aborting."
	exit 1
fi

KERNEL=$(uname -r)
if ! [[ $BOARD =~ ^ugw ]]; then
	# For EdgeRouters, we must check if they are using the v2.0+ firmware,
	# in which case we use a different package with compatible kernel
	# modules. We simply assume that kernel version 4.0.0+ means we are
	# running on v2.0 firmware.
	if dpkg --compare-versions "$KERNEL" gt "4.0.0"; then
		BOARD=$BOARD-v2
		LATEST_FILE=${LATEST_FILE}-v2.0
	else
		BOARD=$BOARD-v1
	fi
fi

case $1 in
	-h | --help | help)
		usage
		;;
	--version | version)
		echo "vyatta-wireguard-installer v${WIREGUARD_INSTALLER_VERSION}"
		exit 0
		;;
	check)
		run_check "$@"
		;;
	install)
		run_install "$@"
		;;
	upgrade)
		run_upgrade "$@"
		;;
	remove)
		run_remove "$@"
		;;
	self-update)
		run_self_update "$@"
		;;
	*)
		# Perform install if we're running as part of post-config.d and
		# WireGuard is supposed to be installed. (BOOTFILE is declared
		# in /etc/init.d/vyatta-router.)
		# Alternatively, we could check $CONSOLE == /dev/console.
		if [[ $BOOTFILE == /config/config.boot ]] && [[ -f $WIREGUARD_DIR/installed ]]; then
			run_install
			exit 0
		fi

		usage
		exit 1
		;;
esac

exit 0
