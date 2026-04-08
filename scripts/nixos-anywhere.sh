#!/usr/bin/env bash

set -e

FLAKE_DIR="/home/weeb/nixos"

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

    echo "==> Preparing host keys for $host"
    temp=$(mktemp -d)
    trap 'rm -rf "$temp"' EXIT

    install -d -m755 "$temp/etc/ssh"
    install -m600 "$keypath" "$temp/etc/ssh/ssh_host_ed25519_key"
    install -m644 "$keypath.pub" "$temp/etc/ssh/ssh_host_ed25519_key.pub"

    echo "==> Running nixos-anywhere for $host at $ip"
    nix run github:nix-community/nixos-anywhere -- \
        --flake "$FLAKE_DIR#$host" \
        --target-host "root@$ip" \
        --extra-files "$temp"
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
        reinstall "MoteNote" "$ip" "$FLAKE_DIR/secrets/host-keys/moenote/ssh_host_ed25519_key"
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
echo "  2. Re-enable security.protectKernelImage in system/security/kernel.nix"
echo "  3. Rebuild both machines"
