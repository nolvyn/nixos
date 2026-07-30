#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FLAKE_DIR=$(dirname -- "$SCRIPT_DIR")
TARGET_DISK="/dev/nvme0n1"
temp_dir=""

cleanup() {
    local status=$?

    if [[ -n ${temp_dir:-} && -d $temp_dir ]]; then
        rm -rf -- "$temp_dir"
    fi

    if ((status != 0)); then
        echo >&2
        echo "Installation stopped before completing." >&2
        echo "If you temporarily changed the running target configuration, restore:" >&2
        echo "  - security.protectKernelImage" >&2
        echo "  - root SSH access" >&2
        echo "  - the SSH firewall opening" >&2
    fi
}

trap cleanup EXIT

die() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    echo "Usage: $0 [1|2|3]"
    echo "  1 - Reinstall WeebMachine"
    echo "  2 - Reinstall MoeNote"
    echo "  3 - Custom target"
    exit 1
}

reinstall() {
    local host=$1
    local ip=$2
    local keypath=$3
    local confirmation
    local fingerprint_confirmation

    [[ $host =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid host name: $host"
    [[ $ip =~ ^[A-Za-z0-9][A-Za-z0-9.:%_-]*$ ]] || die "invalid target address: $ip"
    [[ -f $FLAKE_DIR/flake.nix ]] || die "flake.nix not found in $FLAKE_DIR"
    [[ -r $keypath ]] || die "host private key is not readable: $keypath"
    [[ -r $keypath.pub ]] || die "host public key is not readable: $keypath.pub"

    echo "==> Validating flake host $host"
    nix eval --raw --no-update-lock-file \
        "$FLAKE_DIR#nixosConfigurations.$host.config.networking.hostName" >/dev/null

    echo
    echo "==> Target SSH ED25519 fingerprint reported by $ip"
    ssh-keyscan -T 5 -t ed25519 "$ip" 2>/dev/null | ssh-keygen -lf -
    echo "Compare this fingerprint with the target console or another trusted source."
    read -rp "Type 'VERIFY $host' after checking it: " fingerprint_confirmation
    [[ $fingerprint_confirmation == "VERIFY $host" ]] || die "SSH fingerprint was not confirmed"

    echo
    echo "==> Target disk reported by $host"
    ssh "root@$ip" lsblk -d -o NAME,PATH,MODEL,SERIAL,SIZE,TYPE "$TARGET_DISK"
    echo
    echo "nixos-anywhere will erase and reinstall $TARGET_DISK on $host ($ip)."
    read -rp "Type 'ERASE $host $TARGET_DISK' to continue: " confirmation
    [[ $confirmation == "ERASE $host $TARGET_DISK" ]] || die "disk erase was not confirmed"

    echo "==> Preparing host keys for $host"
    temp_dir=$(mktemp -d)

    install -d -m755 "$temp_dir/etc/ssh"
    install -m600 "$keypath" "$temp_dir/etc/ssh/ssh_host_ed25519_key"
    install -m644 "$keypath.pub" "$temp_dir/etc/ssh/ssh_host_ed25519_key.pub"

    echo "==> Running nixos-anywhere for $host at $ip"
    nix run github:nix-community/nixos-anywhere -- \
        --flake "$FLAKE_DIR#$host" \
        --target-host "root@$ip" \
        --extra-files "$temp_dir"
}

echo "Nixos-anywhere reinstall script"
echo "================================"
echo "Before running, make sure:"
echo "  1. security.protectKernelImage is commented out and target is rebuilt, OR target is booted from NixOS USB"
echo "  2. Root SSH login is enabled on target"
echo "  3. SSH port 22 is open on target"
echo ""
echo "Select target:"
echo "  1) WeebMachine"
echo "  2) MoeNote"
echo "  3) Custom"
read -rp "Choice: " choice

case $choice in
    1)
        read -rp "WeebMachine IP: " ip
        reinstall "WeebMachine" "$ip" "$FLAKE_DIR/secrets/host-keys/weebmachine/ssh_host_ed25519_key"
        ;;
    2)
        read -rp "MoeNote IP: " ip
        reinstall "MoeNote" "$ip" "$FLAKE_DIR/secrets/host-keys/moenote/ssh_host_ed25519_key"
        ;;
    3)
        read -rp "Hostname (must match flake nixosConfigurations): " host
        read -rp "IP address: " ip
        read -rp "Path to host key (without .pub): " keypath
        reinstall "$host" "$ip" "$keypath"
        ;;
    *)
        usage
        ;;
esac

echo ""
echo "==> Done! Next steps:"
echo "  1. ssh-keygen -R $ip"
echo "  2. Re-enable security.protectKernelImage in modules/aspects/security/kernel.nix"
echo "  3. Rebuild both machines"
