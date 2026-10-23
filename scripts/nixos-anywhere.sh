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
    echo "Usage: $0"
    echo "Run without arguments; choose 1 or 2 at the interactive Choice prompt."
    echo "  1 - Reinstall WeebMachine"
    echo "  2 - Custom target"
    exit 1
}

reinstall() {
    local host=$1
    local ip=$2
    local keypath=$3
    local confirmation
    local fingerprint_confirmation
    local scanned_keys
    local installer
    local extra_files
    local -a ssh_options

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
    temp_dir=$(mktemp -d)
    ssh-keyscan -T 5 -t ed25519 "$ip" >"$temp_dir/keyscan" 2>/dev/null
    scanned_keys=$(awk '$2 == "ssh-ed25519" { print $2, $3 }' "$temp_dir/keyscan" | sort -u)
    [[ -n $scanned_keys && $scanned_keys != *$'\n'* ]] || die "target must present exactly one ED25519 key"
    printf 'nixos-anywhere-verified %s\n' "$scanned_keys" >"$temp_dir/known_hosts"
    chmod 400 "$temp_dir/known_hosts"
    ssh-keygen -lf "$temp_dir/known_hosts"
    echo "Compare this fingerprint with the target console or another trusted source."
    read -rp "Type 'VERIFY $host' after checking it: " fingerprint_confirmation
    [[ $fingerprint_confirmation == "VERIFY $host" ]] || die "SSH fingerprint was not confirmed"

    # Keep these controls in sync with nixos-anywhere-trusted.nix. Options must
    # precede upstream defaults: OpenSSH uses the first value of each option.
    export NIXOS_ANYWHERE_KNOWN_HOSTS="$temp_dir/known_hosts"
    ssh_options=(
        -o StrictHostKeyChecking=yes
        -o "UserKnownHostsFile=$NIXOS_ANYWHERE_KNOWN_HOSTS"
        -o GlobalKnownHostsFile=/dev/null
        -o KnownHostsCommand=none
        -o VerifyHostKeyDNS=no
        -o NoHostAuthenticationForLocalhost=no
        -o HostKeyAlgorithms=ssh-ed25519
        -o HostKeyAlias=nixos-anywhere-verified
        -o CheckHostIP=no
        -o UpdateHostKeys=no
        -o ControlPath=none
    )

    echo
    echo "==> Target disk reported by $host"
    ssh "${ssh_options[@]}" "root@$ip" lsblk -d -o NAME,PATH,MODEL,SERIAL,SIZE,TYPE "$TARGET_DISK"
    echo
    echo "nixos-anywhere will erase and reinstall $TARGET_DISK on $host ($ip)."
    read -rp "Type 'ERASE $host $TARGET_DISK' to continue: " confirmation
    [[ $confirmation == "ERASE $host $TARGET_DISK" ]] || die "disk erase was not confirmed"

    echo "==> Preparing host keys for $host"
    extra_files="$temp_dir/extra-files"
    install -d -m755 "$extra_files/persistent/etc/ssh"
    install -m600 "$keypath" "$extra_files/persistent/etc/ssh/ssh_host_ed25519_key"
    install -m644 "$keypath.pub" "$extra_files/persistent/etc/ssh/ssh_host_ed25519_key.pub"

    echo "==> Running nixos-anywhere for $host at $ip"
    installer=$(nix build --impure --no-link --print-out-paths \
        --file "$SCRIPT_DIR/nixos-anywhere-trusted.nix")
    "$installer/bin/nixos-anywhere" \
        --flake "$FLAKE_DIR#$host" \
        --target-host "root@$ip" \
        --extra-files "$extra_files"
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
echo "  2) Custom"
read -rp "Choice: " choice

case $choice in
    1)
        read -rp "WeebMachine IP: " ip
        reinstall "WeebMachine" "$ip" "$FLAKE_DIR/secrets/host-keys/weebmachine/ssh_host_ed25519_key"
        ;;
    2)
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
