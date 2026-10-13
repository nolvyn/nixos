#!/usr/bin/env bash

# This file is embedded in the initrd unit; functions are also usable by fixtures.
set -Eeuo pipefail

archive_subvolume() {
    local source=$1 archive_dir=$2 archived_at=$3 destination counter=0
    mkdir -p -- "$archive_dir"
    while :; do
        destination="$archive_dir/archived-$archived_at-$counter"
        [[ -e $destination || -L $destination ]] || break
        counter=$((counter + 1))
    done
    mv -T -- "$source" "$destination"
}

prune_archives() {
    local archive_dir=$1 now=$2 archive archived_at
    local cutoff=$((now - 30 * 24 * 60 * 60))
    for archive in "$archive_dir"/*; do
        [[ -d $archive && ! -L $archive ]] || continue
        # Refuse to delete ordinary directories or symlink destinations.
        btrfs subvolume show "$archive" >/dev/null 2>&1 || continue
        if [[ ${archive##*/} =~ ^archived-([0-9]{10})-[0-9]+$ ]]; then
            archived_at=$((10#${BASH_REMATCH[1]}))
            if ((archived_at <= cutoff)); then
                btrfs subvolume delete --recursive "$archive"
            fi
        elif [[ ${archive##*/} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{1,2}_[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
            # Legacy names reflect live mtimes, not archive age. Give them a
            # complete retention window rather than guessing their creation time.
            archive_subvolume "$archive" "$archive_dir" "$now"
        fi
    done
}

rollback_btrfs() {
    local root=/btrfs_tmp now
    mkdir -p -- "$root"
    mount -o subvolid=5 /dev/mapper/cryptroot "$root"
    trap 'umount /btrfs_tmp' EXIT
    now=$(date +%s)
    mkdir -p -- "$root/@old_roots" "$root/@old_home_roots"
    if [[ -e $root/@ ]]; then
        archive_subvolume "$root/@" "$root/@old_roots" "$now"
    fi
    if [[ -e $root/@home ]]; then
        archive_subvolume "$root/@home" "$root/@old_home_roots" "$now"
    fi
    prune_archives "$root/@old_roots" "$now"
    prune_archives "$root/@old_home_roots" "$now"
    btrfs subvolume create "$root/@"
    btrfs subvolume create "$root/@home"
    umount "$root"
    trap - EXIT
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    rollback_btrfs
fi
