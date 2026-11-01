#!/usr/bin/env bash
# Initrd checkpoint transaction. All disk-changing tests use disposable guests.
set -Eeuo pipefail
export LC_ALL=C
RB_UUID='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
RB_PROOF=rollback-checkpoints-v7
RB_MAX_CLONES=4
RB_MAX_KEPT=24
RB_MAX_INTENTS=8
rb_error() { printf >&2 'rollback: %s\n' "$*"; return 1; }
rb_exists() { [[ -e $1 || -L $1 ]]; }
rb_dir() { [[ -d $1 && ! -L $1 ]]; }
rb_subvol() { rb_dir "$1" && btrfs subvolume show "$1" >/dev/null 2>&1; }
rb_uuid() {
    local output line value found=
    output=$(btrfs subvolume show "$1") || return
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*UUID:[[:space:]]*($RB_UUID)$ ]]; then
            [[ -z $found ]] || return 1
            found=${BASH_REMATCH[1]}
        fi
    done <<< "$output"
    [[ -n $found ]] || return 1
    printf '%s\n' "$found"
}
rb_parent() {
    local output line
    output=$(btrfs subvolume show "$1") || return
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*Parent[[:space:]]UUID:[[:space:]]*($RB_UUID)$ ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"; return 0
        fi
    done <<< "$output"
    return 1
}
rb_fs_uuid() {
    local uuid
    uuid=$(findmnt --noheadings --output UUID --target "$1") || return
    [[ $uuid =~ ^$RB_UUID$ ]] || return 1
    printf '%s\n' "$uuid"
}

rb_ro() { [[ $(btrfs property get -ts "$1" ro) == "ro=true" ]]; }
rb_rw() { [[ $(btrfs property get -ts "$1" ro) == "ro=false" ]]; }
rb_identity() { rb_subvol "$1" && [[ $(rb_uuid "$1") == "$2" ]]; }
rb_proof() {
    local size
    [[ -f $1/proof && ! -L $1/proof ]] || return 1
    size=$(stat -c %s -- "$1/proof") || return
    [[ $size == "$((${#RB_PROOF} + 1))" ]] || return 1
    [[ $(< "$1/proof") == "$RB_PROOF" ]]
}
rb_link_valid() { [[ -f $2 && ! -L $2 && $1/proof -ef $2 ]] && rb_proof "$1"; }
rb_publish() {
    local tx=$1 path=$2
    rb_proof "$tx" || return
    if rb_exists "$path"; then rb_link_valid "$tx" "$path"; else ln -T -- "$tx/proof" "$path"; fi
}
rb_sync() { sync -f "$1"; }
rb_children() { rb_tree_capture "$1" >/dev/null; }
# The helper enumerates every direct child and queries every child for deeper
# descendants. A successful query also proves quotas and squotas disabled.
rb_tree_capture() {
    timeout --signal=TERM --kill-after=1s 15s rollback-tree-metadata "$1"
}
rb_tree_parse() {
    local file=$1 line kind a b c d extra n=0 seen='|' ids='|' size
    [[ -f $file && ! -L $file ]] || return 1
    size=$(stat -c %s -- "$file") || return
    ((size > 0 && size <= 20000)) || return 1
    while IFS='|' read -r kind a b c d extra; do
        [[ -z $extra && $b =~ ^$RB_UUID$ && $c =~ ^$RB_UUID$ && $d =~ ^[01]$ ]] || return 1
        if ((n == 0)); then
            [[ $kind == TREE && $a =~ ^$RB_UUID$ ]] || return 1
        else
            [[ $kind == LEAF && -n $a && $a != /* && $a != */ && $a != *'//'* && $a != *'\'* ]] || return 1
            [[ /$a/ != */../* && /$a/ != */./* && $a != *$'\t'* && $a != *$'\r'* ]] || return 1
            [[ $seen != *"|$a|"* && $ids != *"|$b|"* ]] || return 1
            seen+="$a|";ids+="$b|"
        fi
        n=$((n+1));((n<=17)) || return 1
    done < "$file"
    ((n>=1))
}
rb_tree_room() {
    local directory=$1 path=$2 entry count=0
    rb_exists "$path" && return 0
    for entry in "$directory"/*;do rb_exists "$entry" && count=$((count+1));done
    ((count<256)) || { rb_error 'tree metadata record budget exhausted';return 1; }
}
rb_tree_record() {
    local tx=$1 category=$2 role=$3 path=$4 data uuid digest key map planned receipt
    data=$(rb_tree_capture "$path") || return
    IFS='|' read -r _ _ uuid _ _ <<< "$data"
    [[ $uuid =~ ^$RB_UUID$ ]] || return 1
    digest=$(printf '%s\n' "$data" | sha256sum) || return;digest=${digest%% *}
    key=$role-$uuid-$digest;map=$tx/tree-maps/$uuid-$digest
    planned=$tx/tree-planned/$key;receipt=$tx/tree-$category/$key
    rb_tree_room "$tx/tree-planned" "$planned" && rb_tree_room "$tx/tree-maps" "$map" && rb_tree_room "$tx/tree-$category" "$receipt" || return
    if ! rb_exists "$planned";then
        # Do not adopt an existing unowned file merely because bytes match.
        ! rb_exists "$map" || return 1
        rb_publish "$tx" "$planned" && rb_sync "$tx" || return
    else rb_link_valid "$tx" "$planned" || return 1;fi
    if rb_exists "$map";then
        rb_tree_parse "$map" && [[ $(< "$map") == "$data" ]] || return 1
    else
        # Unnamed O_TMPFILE records disappear on interruption before linkat.
        # The durable intent binds the exact UUID/digest before publication.
        printf '%s\n' "$data" | timeout --signal=TERM --kill-after=1s 15s rollback-tree-record "$tx/tree-maps" "$uuid-$digest" || return
    fi
    rb_publish "$tx" "$receipt" && rb_sync "$tx"
}

rb_tree_files() {
    local tx=$1 category=$2 role=$3 uuid=$4 entry digest map actual kind fs recorded parent flag
    for entry in "$tx/tree-$category/$role-$uuid-"*; do
        rb_exists "$entry" || continue
        digest=${entry##*-};[[ $digest =~ ^[0-9a-f]{64}$ ]] || return 1
        rb_link_valid "$tx" "$entry" || return 1
        map=$tx/tree-maps/$uuid-$digest
        rb_tree_parse "$map" || return
        IFS='|' read -r kind fs recorded parent flag < "$map"
        [[ $recorded == "$uuid" ]] || return 1
        actual=$(sha256sum -- "$map") || return
        [[ ${actual%% *} == "$digest" ]] || return 1
        printf '%s\n' "$map"
    done
}
rb_tree_one() {
    local files
    files=$(rb_tree_files "$@") || return
    [[ -n $files && $files != *$'\n'* ]] || return 1
    printf '%s\n' "$files"
}
rb_tree_source() {
    local index=9
    [[ $2 == root ]] || index=10
    rb_tree_one "$1" source "$2" "${RB_M[index]}"
}
rb_tree_expected() {
    local map=$1 mode=$2 layout=${3:-} kind a b c d extra flag row found value
    while IFS='|' read -r kind a b c d extra; do
        if [[ $kind == TREE && $mode != pristine ]]; then d=0;fi
        if [[ $kind == LEAF && $mode == exposed ]]; then
            found=false
            while IFS='|' read -r row flag _ _ value; do
                if [[ $row == LEAF && $flag == "$a" ]];then d=$value;found=true;break;fi
            done < "$layout"
            [[ $found == true ]] || return 1
        fi
        printf '%s|%s|%s|%s|%s\n' "$kind" "$a" "$b" "$c" "$d"
    done < "$map"
}
rb_tree_validate() {
    local tx=$1 category=$2 role=$3 path=$4 mode=${5:-pristine} uuid actual files map expected layout= matches=0
    uuid=$(rb_uuid "$path") || return
    actual=$(rb_tree_capture "$path") || return
    files=$(rb_tree_files "$tx" "$category" "$role" "$uuid") || return
    [[ -n $files ]] || return 1
    if [[ $category != acquiring ]]; then [[ $files != *$'\n'* ]] || return 1;fi
    if [[ $mode == exposed ]];then layout=$(rb_tree_source "$tx" "$role") || return;fi
    while IFS= read -r map; do
        expected=$(rb_tree_expected "$map" "$mode" "$layout") || return
        [[ $actual != "$expected" ]] || matches=$((matches+1))
    done <<< "$files"
    [[ $matches == 1 ]]
}
rb_tree_lineage() {
    local source=$1 target=$2 sk sp su parent flags tk tp tu tparent tf count=0 matches=0
    while IFS='|' read -r sk sp su parent flags; do
        [[ $sk == LEAF ]] || continue
        count=$((count+1))
        while IFS='|' read -r tk tp tu tparent tf; do
            [[ $tk != LEAF || $tp != "$sp" ]] || { [[ $tparent == "$su" && $tf == 1 ]] || return 1;matches=$((matches+1)); }
        done < "$target"
    done < "$source"
    local actual=0
    while IFS='|' read -r tk _ _ _ tf; do [[ $tf == 1 ]] || return 1;[[ $tk != LEAF ]] || actual=$((actual+1));done < "$target"
    [[ $matches == "$count" && $actual == "$count" ]]
}
rb_tree_construct() {
    local source=$1 dest=$2 expected=${3:-} original after kind path uuid parent flag output
    original=$(rb_tree_capture "$source") || return
    [[ -z $expected || $original == "$expected" ]] || { rb_error 'source layout changed before construction';return 1; }
    btrfs subvolume snapshot "$source" "$dest" >/dev/null || return
    while IFS='|' read -r kind path uuid parent flag; do
        [[ $kind == LEAF ]] || continue
        # A nested subvolume becomes an empty inode-2 directory in a parent
        # snapshot. Remove only that newly created verified empty stub.
        [[ -d $dest/$path && ! -L $dest/$path && $(stat -c %i -- "$dest/$path") == 2 ]] || return 1
        rmdir -- "$dest/$path" || return
        btrfs subvolume snapshot -r "$source/$path" "$dest/$path" >/dev/null || return
    done <<< "$original"
    btrfs property set -ts "$dest" ro true || return
    after=$(rb_tree_capture "$source") || return
    [[ $original == "$after" ]] || { rb_error 'source tree changed during construction';return 1; }
}
rb_tree_created() {
    local tx=$1 role=$2 path=$3 source=$4 uuid map source_map
    uuid=$(rb_uuid "$path") || return
    rb_tree_record "$tx" created "$role" "$path" || return
    map=$(rb_tree_one "$tx" created "$role" "$uuid") || return
    source_map=$(rb_tree_capture "$source") || return
    rb_tree_lineage <(printf '%s\n' "$source_map") "$map"
}
rb_tree_parked_valid() {
    local tx=$1 role=$2 path=$3 uuid
    uuid=$(rb_uuid "$path") || return
    if rb_exists "$tx/parked/$role-$uuid";then rb_tree_validate "$tx" parked "$role" "$path";else rb_tree_validate "$tx" acquiring "$role" "$path";fi
}
rb_tree_ack_parked() {
    local tx=$1 role=$2 path=$3 uuid data file files expected count=0 chosen=
    uuid=$(rb_uuid "$path") || return
    data=$(rb_tree_capture "$path") || return
    files=$(rb_tree_files "$tx" acquiring "$role" "$uuid") || return
    while IFS= read -r file; do
        [[ -n $file ]] || continue
        if [[ $(< "$file") == "$data" ]];then chosen=$file;count=$((count+1));fi
    done <<< "$files"
    [[ $count == 1 ]] || return 1
    rb_publish "$tx" "$tx/tree-parked/$role-${chosen##*/}" || return
    rb_sync "$tx"
}
rb_tree_metadata_valid() {
    local tx=$1 dir entry name count digest uuid role map actual kind fs recorded parent flag root_proof home_proof
    for dir in tree-maps tree-planned tree-source tree-created tree-acquiring tree-parked; do
        rb_dir "$tx/$dir" || return 1;count=0
        for entry in "$tx/$dir"/* "$tx/$dir"/.[!.]* "$tx/$dir"/..?*;do
            rb_exists "$entry" || continue;count=$((count+1));((count<=256)) || return 1
            name=${entry##*/}
            case $dir in
                tree-maps)
                    [[ $name =~ ^($RB_UUID)-([0-9a-f]{64})$ ]] || return 1
                    uuid=${BASH_REMATCH[1]};digest=${BASH_REMATCH[2]}
                    rb_tree_parse "$entry" || return
                    actual=$(sha256sum -- "$entry") || return
                    [[ ${actual%% *} == "$digest" ]] || return 1
                    IFS='|' read -r kind fs recorded parent flag < "$entry"
                    [[ $recorded == "$uuid" && $fs == "${RB_M[1]}" ]] || return 1
                    root_proof=false;home_proof=false
                    if rb_link_valid "$tx" "$tx/tree-planned/root-$name";then root_proof=true;fi
                    if rb_link_valid "$tx" "$tx/tree-planned/home-$name";then home_proof=true;fi
                    [[ $root_proof != "$home_proof" ]] || return 1
                    ;;
                *)
                    [[ $name =~ ^(root|home)-($RB_UUID)-([0-9a-f]{64})$ ]] && rb_link_valid "$tx" "$entry" || return 1
                    if [[ $dir != tree-planned ]];then
                        rb_link_valid "$tx" "$tx/tree-planned/$name" || return 1
                        map=$tx/tree-maps/${name#*-};rb_tree_parse "$map" || return
                    fi
                    ;;
            esac
        done
    done
}
rb_tree_expose_flags() {
    local tx=$1 role=$2 source=$3 layout kind path uuid parent flag
    layout=$(rb_tree_source "$tx" "$role") || return
    btrfs property set -ts "$source" ro false || return
    while IFS='|' read -r kind path uuid parent flag;do
        [[ $kind == LEAF ]] || continue
        # Fresh empty roots have no leaves; restore clones have every leaf.
        [[ -e $source/$path ]] || continue
        if [[ $flag == 1 ]];then btrfs property set -ts "$source/$path" ro true || return
        else btrfs property set -ts "$source/$path" ro false || return;fi
    done < "$layout"
    rb_tree_validate "$tx" created "$role" "$source" exposed
}
rb_tree_cleanup() {
    local tx=$1 file map dir linked receipt digest actual
    # A published map must match an exact durable creation intent. Unknown
    # files or byte-only lookalikes are never silently adopted or removed.
    for map in "$tx/tree-maps"/*; do
        rb_exists "$map" || continue;linked=false
        rb_tree_parse "$map" || return
        digest=${map##*-};actual=$(sha256sum -- "$map") || return
        [[ ${actual%% *} == "$digest" ]] || return 1
        for receipt in "$tx/tree-planned"/*-"${map##*/}";do
            rb_exists "$receipt" && rb_link_valid "$tx" "$receipt" && linked=true
        done
        [[ $linked == true ]] || return 1
    done
    for dir in tree-source tree-created tree-acquiring tree-parked tree-maps tree-planned;do
        for file in "$tx/$dir"/*;do rb_exists "$file" && rm -- "$file" || { rb_exists "$file" && return 1; };done
        rmdir -- "$tx/$dir" || return
    done
}

rb_archive_path() {
    local directory=$1 epoch=$2 counter=0 path
    while :; do path=$directory/archived-$epoch-$counter; rb_exists "$path" || break; counter=$((counter + 1)); done
    printf '%s\n' "$path"
}
rb_prune() {
    local directory=$1 now=$2 path epoch dest
    rb_dir "$directory" || return 1
    for path in "$directory"/*; do
        rb_subvol "$path" || continue
        if [[ ${path##*/} =~ ^archived-([0-9]{10})-[0-9]+$ ]]; then
            epoch=$((10#${BASH_REMATCH[1]}))
            if ((epoch <= now - 2592000)); then btrfs subvolume delete --recursive "$path" || return; fi
        elif [[ ${path##*/} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{1,2}_[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
            dest=$(rb_archive_path "$directory" "$now") || return
            mv -T -- "$path" "$dest" || return
        fi
    done
}
# A complete immutable manifest is synced before the canonical journal exists.
# Globals are scoped by rollback_btrfs's subshell; fixtures can inspect them too.
rb_manifest() {
    local tx=$1 root=$2 line entry name role uuid count=0 size
    rb_dir "$tx" && rb_proof "$tx" || return 1
    [[ -f $tx/manifest && ! -L $tx/manifest ]] || return 1
    size=$(stat -c %s -- "$tx/manifest") || return
    [[ $size =~ ^[0-9]+$ ]] && ((size <= 1024)) || return 1
    mapfile -n 13 -t RB_M < "$tx/manifest" || return
    [[ ${#RB_M[@]} == 12 && ${RB_M[0]} == "$RB_PROOF" ]] || return 1
    [[ ${RB_M[1]} =~ ^$RB_UUID$ && ${RB_M[1]} == "$(rb_fs_uuid "$root")" ]] || return 1
    [[ ${RB_M[2]} =~ ^[0-9]{10}-[0-9]+$ ]] || return 1
    for uuid in "${RB_M[@]:3}"; do [[ $uuid =~ ^$RB_UUID$ ]] || return 1; done
    # checkpoint root/home, fresh root/home, initial clones root/home, source
    # root/home and transaction nonce. Duplicate IDs are never interchangeable.
    for uuid in "${RB_M[@]:3}"; do
        for line in "${RB_M[@]:3}"; do [[ $uuid != "$line" ]] || count=$((count + 1)); done
    done
    [[ $count == 9 ]] || return 1
    for entry in "$tx"/* "$tx"/.[!.]* "$tx"/..?*; do
        rb_exists "$entry" || continue; name=${entry##*/}
        case $name in
            manifest|proof) [[ -f $entry && ! -L $entry ]] || return 1 ;;
            owned|created|acquiring|parked|exposed|kept|intents|published|tree-maps|tree-planned|tree-source|tree-created|tree-acquiring|tree-parked) rb_dir "$entry" || return 1 ;;
            checkpoint-root|checkpoint-home|new-root|new-home|clone-root-[0-3]|clone-home-[0-3]) rb_subvol "$entry" && [[ $(rb_fs_uuid "$entry") == "${RB_M[1]}" ]] || return 1 ;;
            committed|recovered|slot-root-[0-3]|slot-home-[0-3]) rb_link_valid "$tx" "$entry" || return 1 ;;
            resolved-*) [[ $name =~ ^resolved-($RB_UUID)-($RB_UUID)$ ]] && rb_link_valid "$tx" "$entry" || return 1 ;;
            *) return 1 ;;
        esac
    done
    for name in owned created acquiring parked exposed kept intents published; do rb_dir "$tx/$name" || return 1; done
    for name in checkpoint-root checkpoint-home new-root new-home clone-root-0 clone-home-0; do
        case $name in checkpoint-root) count=3;; checkpoint-home) count=4;; new-root) count=5;; new-home) count=6;; clone-root-0) count=7;; clone-home-0) count=8;; esac
        role=root; [[ $name != *home* ]] || role=home
        rb_link_valid "$tx" "$tx/owned/$role-${RB_M[count]}" && rb_link_valid "$tx" "$tx/created/$role-${RB_M[count]}" || return 1
        if rb_exists "$tx/$name"; then rb_identity "$tx/$name" "${RB_M[count]}" || return 1; fi
    done
    for role in root home; do
        count=3; [[ $role == root ]] || count=4
        for entry in "$tx"/clone-$role-[0-3]; do
            rb_exists "$entry" || continue
            [[ $(rb_parent "$entry") == "${RB_M[count]}" ]] || return 1
            rb_link_valid "$tx" "$tx/slot-$role-${entry##*-}" || return 1
            uuid=$(rb_uuid "$entry") || return
            # A crash immediately after snapshot creation may precede ownership
            # publication. Only a read-only clone at an intent-bound slot with
            # the expected checkpoint parent can complete that publication.
            if ! rb_exists "$tx/owned/$role-$uuid"; then rb_tree_capture "$entry" >/dev/null || return; fi
        done
    done
    for name in owned created acquiring parked exposed; do
        for entry in "$tx/$name"/* "$tx/$name"/.[!.]* "$tx/$name"/..?*; do
            rb_exists "$entry" || continue
            [[ ${entry##*/} =~ ^(root|home)-($RB_UUID)$ ]] && rb_link_valid "$tx" "$entry" || return 1
            role=${BASH_REMATCH[1]}; uuid=${BASH_REMATCH[2]}
            line=home; [[ $role == root ]] || line=root
            for count in owned created acquiring parked exposed; do
                ! rb_exists "$tx/$count/$line-$uuid" || return 1
            done
            case $name in
                created) rb_link_valid "$tx" "$tx/owned/$role-$uuid" || return 1 ;;
                parked) rb_link_valid "$tx" "$tx/owned/$role-$uuid" && rb_link_valid "$tx" "$tx/acquiring/$role-$uuid" || return 1 ;;
                exposed)
                    rb_link_valid "$tx" "$tx/created/$role-$uuid" || return 1
                    [[ $uuid != "${RB_M[3]}" && $uuid != "${RB_M[4]}" ]] || return 1 ;;
            esac
        done
    done
    for name in intents published; do
        for entry in "$tx/$name"/* "$tx/$name"/.[!.]* "$tx/$name"/..?*; do
            rb_exists "$entry" || continue
            [[ ${entry##*/} =~ ^(root|home)-($RB_UUID)-([0-9]{10})$ ]] && rb_link_valid "$tx" "$entry" || return 1
        done
    done
    for entry in "$tx/kept"/* "$tx/kept"/.[!.]* "$tx/kept"/..?*; do
        rb_exists "$entry" || continue
        [[ ${entry##*/} =~ ^$RB_UUID$ ]] || return 1
        uuid=${entry##*/}; rb_identity "$entry" "$uuid" && [[ $(rb_fs_uuid "$entry") == "${RB_M[1]}" ]] || return 1
        [[ -e $tx/owned/root-$uuid || -e $tx/owned/home-$uuid || -e $tx/acquiring/root-$uuid || -e $tx/acquiring/home-$uuid ]] || return 1
    done
    rb_tree_metadata_valid "$tx"
}
rb_registry_room() {
    local tx=$1 role=$2 uuid=$3 other=home entry count=0 name
    [[ $role == root ]] || other=root
    [[ $uuid =~ ^$RB_UUID$ ]] || return 1
    for name in owned created acquiring parked exposed; do ! rb_exists "$tx/$name/$other-$uuid" || return 1; done
    if ! rb_exists "$tx/owned/$role-$uuid"; then
        for entry in "$tx/owned"/*; do rb_exists "$entry" && count=$((count + 1)); done
        ((count < RB_MAX_KEPT + 8)) || { rb_error 'ownership budget exhausted; rollback suspended'; return 1; }
    fi
}
rb_register() {
    rb_registry_room "$@" || return
    rb_publish "$1" "$1/owned/$2-$3"
}
rb_register_created() {
    rb_register "$@" || return
    rb_publish "$1" "$1/created/$2-$3"
}
rb_park() {
    local tx=$1 role=$2 source=$3 root=$4 uuid entry count=0
    rb_subvol "$source" || return 1
    uuid=$(rb_uuid "$source") || return
    [[ $uuid != "${RB_M[3]}" && $uuid != "${RB_M[4]}" ]] || return 1
    for entry in "$tx/kept"/*; do rb_exists "$entry" && count=$((count + 1)); done
    ((count < RB_MAX_KEPT)) || { rb_error 'preserved-version budget exhausted; rollback suspended'; return 1; }
    ! rb_exists "$tx/kept/$uuid" || return 1
    rb_registry_room "$tx" "$role" "$uuid" || return
    if ! rb_exists "$tx/acquiring/$role-$uuid"; then
        count=0
        for entry in "$tx/acquiring"/*; do rb_exists "$entry" && count=$((count + 1)); done
        ((count < RB_MAX_KEPT)) || { rb_error 'acquisition budget exhausted; current roots retained'; return 1; }
    fi
    rb_tree_record "$tx" acquiring "$role" "$source" || return
    rb_publish "$tx" "$tx/acquiring/$role-$uuid" || return
    rb_sync "$root" || return
    rb_tree_validate "$tx" acquiring "$role" "$source" || return
    mv -T -- "$source" "$tx/kept/$uuid" || return
    rb_sync "$root" || return
    # References and intents are not acknowledgements of acquired custody.
    rb_tree_validate "$tx" acquiring "$role" "$tx/kept/$uuid" || return
    rb_tree_ack_parked "$tx" "$role" "$tx/kept/$uuid" || return
    rb_register "$tx" "$role" "$uuid" || return
    rb_publish "$tx" "$tx/parked/$role-$uuid" || return
    rb_sync "$root"
}
rb_resume_acquisitions() {
    local tx=$1 root=$2 entry role uuid
    for entry in "$tx/acquiring"/*; do
        rb_exists "$entry" || continue
        [[ ${entry##*/} =~ ^(root|home)-($RB_UUID)$ ]] || return 1
        role=${BASH_REMATCH[1]};uuid=${BASH_REMATCH[2]}
        if rb_exists "$tx/kept/$uuid"; then
            rb_identity "$tx/kept/$uuid" "$uuid" && rb_tree_parked_valid "$tx" "$role" "$tx/kept/$uuid" || return 1
            rb_tree_ack_parked "$tx" "$role" "$tx/kept/$uuid" || return
            rb_register "$tx" "$role" "$uuid" || return
            rb_publish "$tx" "$tx/parked/$role-$uuid" || return
            rb_sync "$root" || return
        elif ! rb_exists "$tx/parked/$role-$uuid"; then
            printf >&2 'rollback: acquisition not acknowledged for %s/%s; no protected-copy claim\n' "$role" "$uuid"
        fi
    done
}
rb_active_inventory() {
    local tx=$1 entry role uuid source
    for entry in "$tx/owned"/*; do
        rb_exists "$entry" || continue
        [[ ${entry##*/} =~ ^(root|home)-($RB_UUID)$ ]] || return 1
        role=${BASH_REMATCH[1]};uuid=${BASH_REMATCH[2]}
        source=$(rb_find_owned "$tx" "$uuid") || return
        if [[ -n $source ]];then
            if rb_exists "$tx/parked/$role-$uuid";then rb_tree_validate "$tx" parked "$role" "$source" || return;fi
            continue
        fi
        if rb_exists "$tx/parked/$role-$uuid"; then
            rb_error "missing acknowledged parked version: $role/$uuid";return 1
        fi
        rb_link_valid "$tx" "$tx/created/$role-$uuid" && rb_link_valid "$tx" "$tx/exposed/$role-$uuid" || { rb_error "missing unexposed protected object: $role/$uuid";return 1; }
    done
}
rb_expose() {
    local tx=$1 role=$2 source=$3 target=$4 root=$5 uuid
    rb_subvol "$source" && rb_ro "$source" && ! rb_exists "$target" || return 1
    uuid=$(rb_uuid "$source") || return
    [[ $uuid != "${RB_M[3]}" && $uuid != "${RB_M[4]}" ]] || return 1
    rb_link_valid "$tx" "$tx/created/$role-$uuid" && ! rb_exists "$tx/parked/$role-$uuid" && rb_tree_validate "$tx" created "$role" "$source" || return 1
    # Only pristine created candidates can leave custody. Acknowledged parked
    # versions are never exposed again while the transaction is unresolved.
    rb_publish "$tx" "$tx/exposed/$role-$uuid" || return
    rb_sync "$root" || return
    rb_tree_expose_flags "$tx" "$role" "$source" || return
    mv -T -- "$source" "$target" || return
    rb_sync "$root"
}
rb_checkpoint_validate() {
    local tx=$1 role=$2 index=3
    [[ $role == root ]] || index=4
    rb_identity "$tx/checkpoint-$role" "${RB_M[index]}" && rb_ro "$tx/checkpoint-$role" && [[ $(rb_parent "$tx/checkpoint-$role") == "${RB_M[index+6]}" ]] && rb_link_valid "$tx" "$tx/owned/$role-${RB_M[index]}" || return 1
    rb_tree_validate "$tx" created "$role" "$tx/checkpoint-$role" || return
    local source_map checkpoint_map
    source_map=$(rb_tree_source "$tx" "$role") && checkpoint_map=$(rb_tree_one "$tx" created "$role" "${RB_M[index]}") || return
    rb_tree_lineage "$source_map" "$checkpoint_map"
}
rb_clone() {
    local tx=$1 role=$2 root=$3 index=3 slot path uuid parent
    [[ $role == root ]] || index=4
    # Only an unexposed read-only clone is reusable. A booted writable clone is
    # preserved as its own version, never assumed pristine from its parent UUID.
    for slot in 0 1 2 3; do
        path=$tx/clone-$role-$slot
        if rb_exists "$path"; then
            rb_subvol "$path" && [[ $(rb_parent "$path") == "${RB_M[index]}" ]] || return 1
            uuid=$(rb_uuid "$path") || return
            rb_link_valid "$tx" "$tx/slot-$role-$slot" || return 1
            if rb_ro "$path"; then
                rb_tree_created "$tx" "$role" "$path" "$tx/checkpoint-$role" || return
                rb_register_created "$tx" "$role" "$uuid" || return
                printf '%s\n' "$path"; return 0; fi
            rb_park "$tx" "$role" "$path" "$root" || return
        fi
    done
    for slot in 0 1 2 3; do
        path=$tx/clone-$role-$slot
        if ! rb_exists "$tx/slot-$role-$slot"; then
            rb_publish "$tx" "$tx/slot-$role-$slot" || return
            rb_sync "$root" || return
            rb_tree_construct "$tx/checkpoint-$role" "$path" || return
            uuid=$(rb_uuid "$path") || return
            [[ $(rb_parent "$path") == "${RB_M[index]}" ]] && rb_ro "$path" || return 1
            rb_tree_created "$tx" "$role" "$path" "$tx/checkpoint-$role" || return
            rb_register_created "$tx" "$role" "$uuid" || return
            rb_sync "$root" || return
            printf '%s\n' "$path"; return 0
        fi
    done
    rb_error 'restore-clone budget exhausted; checkpoints retained, rollback suspended'
}
rb_pair_recovered() {
    local tx=$1 root=$2
    rb_subvol "$root/@" && rb_subvol "$root/@home" && rb_rw "$root/@" && rb_rw "$root/@home" || return 1
    [[ $(rb_parent "$root/@") == "${RB_M[3]}" && $(rb_parent "$root/@home") == "${RB_M[4]}" ]] || return 1
    rb_link_valid "$tx" "$tx/exposed/root-$(rb_uuid "$root/@")" && rb_link_valid "$tx" "$tx/exposed/home-$(rb_uuid "$root/@home")" && rb_tree_validate "$tx" created root "$root/@" exposed && rb_tree_validate "$tx" created home "$root/@home" exposed
}
rb_retire() {
    local root=$1 tx=$1/@rollback-pending r h finished
    r=$(rb_uuid "$root/@") && h=$(rb_uuid "$root/@home") || return
    rb_publish "$tx" "$tx/resolved-$r-$h" || return
    rb_sync "$root" || return
    finished=$root/@rollback-finished-${RB_M[2]}-$r-$h
    ! rb_exists "$finished" || return 1
    mv -T -- "$tx" "$finished" || return
    rb_sync "$root"
}
rb_recover() {
    local root=$1 tx=$1/@rollback-pending clone_root clone_home
    rb_exists "$tx" || return 0
    rb_manifest "$tx" "$root" && rb_checkpoint_validate "$tx" root && rb_checkpoint_validate "$tx" home || { rb_error 'invalid checkpoint journal; retained for inspection'; return 1; }
    rb_resume_acquisitions "$tx" "$root" && rb_active_inventory "$tx" || return
    # A failed exposure can leave writable private candidates. Preserve them
    # as observed versions instead of treating them as pristine empty roots.
    for clone_root in "$tx/new-root" "$tx/new-home"; do
        if rb_exists "$clone_root" && ! rb_ro "$clone_root"; then
            clone_home=root; [[ $clone_root != */new-home ]] || clone_home=home
            rb_park "$tx" "$clone_home" "$clone_root" "$root" || return
        fi
    done
    if rb_exists "$tx/committed" && rb_identity "$root/@" "${RB_M[5]}" && rb_identity "$root/@home" "${RB_M[6]}" && rb_rw "$root/@" && rb_rw "$root/@home" && rb_tree_validate "$tx" created root "$root/@" exposed && rb_tree_validate "$tx" created home "$root/@home" exposed; then
        rb_retire "$root"; return
    fi
    if rb_exists "$tx/recovered" && rb_pair_recovered "$tx" "$root"; then rb_retire "$root"; return; fi
    printf >&2 'rollback: restoring protected checkpoints; preserving distinct live versions\n'
    clone_root=$(rb_clone "$tx" root "$root") || return
    clone_home=$(rb_clone "$tx" home "$root") || return
    # Allocate and validate BOTH clones before moving either current root.
    rb_ro "$clone_root" && rb_ro "$clone_home" || return 1
    rb_sync "$root" || return
    if rb_exists "$root/@"; then rb_park "$tx" root "$root/@" "$root" || return; fi
    if rb_exists "$root/@home"; then rb_park "$tx" home "$root/@home" "$root" || return; fi
    rb_expose "$tx" root "$clone_root" "$root/@" "$root" || return
    rb_expose "$tx" home "$clone_home" "$root/@home" "$root" || return
    rb_sync "$root" || return
    rb_pair_recovered "$tx" "$root" || return 1
    rb_publish "$tx" "$tx/recovered" || return
    rb_sync "$root" || return
    rb_retire "$root"
}
# UUID-derived numeric counters let a durable intent name determine an exact
# old-compatible archive destination without a partially written receipt file.
rb_counter() {
    local value=${1//-/} char result= n
    for ((n=0; n<${#value}; n++)); do char=${value:n:1}; printf -v char '%02d' "$((16#$char))"; result+=$char; done
    printf '%s\n' "$result"
}
rb_find_owned() {
    local tx=$1 uuid=$2 entry found= actual
    for entry in "$tx/checkpoint-root" "$tx/checkpoint-home" "$tx/new-root" "$tx/new-home" "$tx"/clone-root-[0-3] "$tx"/clone-home-[0-3] "$tx/kept/$uuid"; do
        rb_exists "$entry" || continue
        actual=$(rb_uuid "$entry") || return
        if [[ $actual == "$uuid" ]]; then [[ -z $found ]] || return 1; found=$entry; fi
    done
    printf '%s\n' "$found"
}
rb_has_promotion() {
    local tx=$1 role=$2 uuid=$3 entry
    for entry in "$tx/intents/$role-$uuid-"* "$tx/published/$role-$uuid-"*; do
        rb_exists "$entry" && return 0
    done
    return 1
}
rb_finalize() {
    local root=$1 tx=$2 name=${2##*/} released_root released_home entry role uuid source epoch directory dest intent receipt found published=false count last_published value now tree_mode
    [[ $name =~ ^@rollback-finished-([0-9]{10}-[0-9]+)-($RB_UUID)-($RB_UUID)$ ]] || return 1
    released_root=${BASH_REMATCH[2]}; released_home=${BASH_REMATCH[3]}
    rb_manifest "$tx" "$root" || return
    [[ $name == "@rollback-finished-${RB_M[2]}-$released_root-$released_home" ]] && rb_link_valid "$tx" "$tx/resolved-$released_root-$released_home" || return 1
    # Retirement is irreversible: no completed-container path restores live roots.
    for entry in "$tx/owned"/*; do
        rb_exists "$entry" || continue
        [[ ${entry##*/} =~ ^(root|home)-($RB_UUID)$ ]] || return 1
        role=${BASH_REMATCH[1]}; uuid=${BASH_REMATCH[2]}
        source=$(rb_find_owned "$tx" "$uuid") || return
        directory=$root/@old_roots; [[ $role == root ]] || directory=$root/@old_home_roots
        rb_dir "$directory" || return 1
        if [[ -n $source ]]; then
            tree_mode=pristine
            if ! rb_ro "$source" && rb_has_promotion "$tx" "$role" "$uuid";then tree_mode=promoted;fi
            if rb_exists "$tx/parked/$role-$uuid";then rb_tree_validate "$tx" parked "$role" "$source" "$tree_mode" || return
            else rb_tree_validate "$tx" created "$role" "$source" "$tree_mode" || return;fi
            # A delayed retry gets a fresh epoch while the source is protected.
            epoch=$(date +%s) || return
            [[ $epoch =~ ^[0-9]{10}$ ]] || return 1
            intent=$tx/intents/$role-$uuid-$epoch
            if ! rb_exists "$intent"; then
                count=0
                for receipt in "$tx/intents/$role-$uuid-"*; do rb_exists "$receipt" && count=$((count + 1)); done
                ((count < RB_MAX_INTENTS)) || { rb_error 'promotion-intent budget exhausted; completed data retained'; return 1; }
            fi
            rb_publish "$tx" "$intent" || return
            rb_sync "$root" || return
            dest=$directory/archived-$epoch-$(rb_counter "$uuid")
            ! rb_exists "$dest" || { rb_error 'archive destination collision'; return 1; }
            # Btrfs refuses cross-directory rename of a read-only subvolume.
            # This container is irreversibly retired; checkpoints are no longer
            # recovery authorities. Keep the source protected until rename.
            if rb_ro "$source"; then btrfs property set -ts "$source" ro false || return; fi
            mv -T -- "$source" "$dest" || return
            rb_sync "$root" || return
            rb_publish "$tx" "$tx/published/$role-$uuid-$epoch" || return
            rb_sync "$root" || return
        elif ! rb_exists "$tx/parked/$role-$uuid" && rb_link_valid "$tx" "$tx/created/$role-$uuid" && rb_link_valid "$tx" "$tx/exposed/$role-$uuid" && ! rb_has_promotion "$tx" "$role" "$uuid"; then
            # Deliberately exposed candidates can be archived/pruned by legacy
            # code. Never apply this exception to checkpoints or parked data.
            continue
        else
            found=; published=false; last_published=0
            for receipt in "$tx/published/$role-$uuid-"*; do
                rb_exists "$receipt" || continue
                rb_link_valid "$tx" "$receipt" || return 1
                published=true
                value=$((10#${receipt##*-}))
                ((value <= last_published)) || last_published=$value
            done
            for intent in "$tx/intents/$role-$uuid-"*; do
                rb_exists "$intent" || continue
                epoch=${intent##*-}; dest=$directory/archived-$epoch-$(rb_counter "$uuid")
                if rb_exists "$dest"; then
                    rb_identity "$dest" "$uuid" || return 1
                    if rb_exists "$tx/parked/$role-$uuid";then rb_tree_validate "$tx" parked "$role" "$dest" promoted || return
                    else rb_tree_validate "$tx" created "$role" "$dest" promoted || return;fi
                    [[ -z $found ]] || return 1
                    found=$dest
                    rb_publish "$tx" "$tx/published/$role-$uuid-$epoch" || return
                    rb_sync "$root" || return
                fi
            done
            if [[ -z $found && $published == false ]]; then
                rb_error "missing protected object and archive: $role/$uuid; completed receipt retained"; return 1
            fi
            if [[ -z $found && $published == true ]]; then
                now=$(date +%s) || return
                [[ $now =~ ^[0-9]{10}$ ]] || return 1
                if ((10#$now - last_published < 2592000)); then
                    rb_error "published archive missing before retention elapsed: $role/$uuid; receipt retained"; return 1
                fi
            fi
            # Publication plus elapsed retention permits normal expiration;
            # neither a bare intent nor a premature disappearance is success.
        fi
    done
    rb_sync "$root" || return
    # Data objects are gone or explicitly released to live roots; remove only
    # validated receipt metadata. Interrupted metadata cleanup can leave a
    # diagnostic-only container, never permission to restore or delete user data.
    for entry in "$tx/kept"/* "$tx"/clone-root-[0-3] "$tx"/clone-home-[0-3] "$tx/checkpoint-root" "$tx/checkpoint-home" "$tx/new-root" "$tx/new-home"; do
        ! rb_exists "$entry" || return 1
    done
    rb_tree_cleanup "$tx" || return
    for name in owned created acquiring parked exposed intents published; do
        for entry in "$tx/$name"/*; do rb_exists "$entry" && rm -- "$entry" || { rb_exists "$entry" && return 1; }; done
        rmdir -- "$tx/$name" || return
    done
    rmdir -- "$tx/kept" || return
    for entry in "$tx"/*; do [[ -f $entry && ! -L $entry ]] || return 1; rm -- "$entry" || return; done
    rmdir -- "$tx"
}
rb_maintenance() {
    local root=$1 path now
    for path in "$root"/@rollback-finished-*; do
        rb_exists "$path" || continue
        rb_finalize "$root" "$path" || printf >&2 'rollback: completed transaction maintenance suspended: %s\n' "$path"
    done
    now=$(date +%s) || return
    rb_prune "$root/@old_roots" "$now" || printf >&2 'rollback: root retention maintenance failed\n'
    rb_prune "$root/@old_home_roots" "$now" || printf >&2 'rollback: home retention maintenance failed\n'
}
rb_prepare() {
    local root=$1 now id counter=0 prep source_root source_home fs r h nr nh cr ch nonce root_tree home_tree leaf_count line
    source_root=$(rb_uuid "$root/@") && source_home=$(rb_uuid "$root/@home") && fs=$(rb_fs_uuid "$root") || return
    root_tree=$(rb_tree_capture "$root/@") && home_tree=$(rb_tree_capture "$root/@home") || return
    leaf_count=0
    while IFS= read -r line;do [[ $line != LEAF\|* ]] || leaf_count=$((leaf_count+1));done <<< "$root_tree"$'\n'"$home_tree"
    ((leaf_count<=16)) || { rb_error 'combined leaf bound exceeded';return 1; }
    # Do not accumulate another checkpoint set behind suspended promotion or
    # receipt cleanup. Existing mountable roots remain available to the boot.
    for prep in "$root"/@rollback-finished-*; do
        ! rb_exists "$prep" || { rb_error 'completed maintenance pending; new transaction suspended'; return 1; }
    done
    # A prior incomplete preparation never mutated roots. Do not silently
    # resume its stale source identity after an older boot or remove its data.
    for prep in "$root"/@rollback-preparing-*; do
        ! rb_exists "$prep" || { rb_error 'incomplete preparation retained; inspect before another transaction'; return 1; }
    done
    now=$(date +%s) || return
    [[ $now =~ ^[0-9]{10}$ ]] || return 1
    while :; do id=$now-$counter; prep=$root/@rollback-preparing-$id; rb_exists "$prep" || break; counter=$((counter + 1)); done
    mkdir -m 0700 -- "$prep" || return
    mkdir -- "$prep/owned" "$prep/created" "$prep/acquiring" "$prep/parked" "$prep/exposed" "$prep/kept" "$prep/intents" "$prep/published" "$prep/tree-maps" "$prep/tree-planned" "$prep/tree-source" "$prep/tree-created" "$prep/tree-acquiring" "$prep/tree-parked" || return
    (set -o noclobber; printf '%s\n' "$RB_PROOF" > "$prep/proof") || return
    rb_tree_record "$prep" source root "$root/@" && rb_tree_record "$prep" source home "$root/@home" || return
    rb_tree_construct "$root/@" "$prep/checkpoint-root" "$root_tree" || return
    rb_tree_construct "$root/@home" "$prep/checkpoint-home" "$home_tree" || return
    rb_tree_created "$prep" root "$prep/checkpoint-root" "$root/@" && rb_tree_created "$prep" home "$prep/checkpoint-home" "$root/@home" || return
    btrfs subvolume create "$prep/new-root" || return
    btrfs subvolume create "$prep/new-home" || return
    btrfs property set -ts "$prep/new-root" ro true || return
    btrfs property set -ts "$prep/new-home" ro true || return
    rb_tree_record "$prep" created root "$prep/new-root" && rb_tree_record "$prep" created home "$prep/new-home" || return
    rb_tree_construct "$prep/checkpoint-root" "$prep/clone-root-0" || return
    rb_tree_construct "$prep/checkpoint-home" "$prep/clone-home-0" || return
    rb_tree_created "$prep" root "$prep/clone-root-0" "$prep/checkpoint-root" && rb_tree_created "$prep" home "$prep/clone-home-0" "$prep/checkpoint-home" || return
    r=$(rb_uuid "$prep/checkpoint-root") && h=$(rb_uuid "$prep/checkpoint-home") && nr=$(rb_uuid "$prep/new-root") && nh=$(rb_uuid "$prep/new-home") && cr=$(rb_uuid "$prep/clone-root-0") && ch=$(rb_uuid "$prep/clone-home-0") || return
    IFS= read -r nonce < /proc/sys/kernel/random/uuid || return
    [[ $nonce =~ ^$RB_UUID$ ]] || return 1
    for id in "$r" "$nr" "$cr"; do rb_register_created "$prep" root "$id" || return; done
    for id in "$h" "$nh" "$ch"; do rb_register_created "$prep" home "$id" || return; done
    rb_publish "$prep" "$prep/slot-root-0" && rb_publish "$prep" "$prep/slot-home-0" || return
    (set -o noclobber; printf '%s\n' "$RB_PROOF" "$fs" "$now-$counter" "$r" "$h" "$nr" "$nh" "$cr" "$ch" "$source_root" "$source_home" "$nonce" > "$prep/manifest") || return
    rb_sync "$root" || return
    rb_manifest "$prep" "$root" && rb_checkpoint_validate "$prep" root && rb_checkpoint_validate "$prep" home || return
    rb_identity "$root/@" "$source_root" && rb_identity "$root/@home" "$source_home" || return 1
    [[ $(rb_tree_capture "$root/@") == "$root_tree" && $(rb_tree_capture "$root/@home") == "$home_tree" ]] || return 1
    ! rb_exists "$root/@rollback-pending" || return 1
    mv -T -- "$prep" "$root/@rollback-pending" || return
    rb_sync "$root"
}
rb_forward() {
    local root=$1 tx=$1/@rollback-pending
    rb_manifest "$tx" "$root" || return
    rb_park "$tx" root "$root/@" "$root" || return
    rb_park "$tx" home "$root/@home" "$root" || return
    rb_expose "$tx" root "$tx/new-root" "$root/@" "$root" || return
    rb_expose "$tx" home "$tx/new-home" "$root/@home" "$root" || return
    rb_sync "$root" || return
    rb_publish "$tx" "$tx/committed" || return
    rb_sync "$root" || return
    rb_retire "$root"
}
rb_fallback() {
    local root=$1 tx=$1/@rollback-pending role target entry uuid index
    rb_exists "$tx" || return 0
    rb_manifest "$tx" "$root" && rb_checkpoint_validate "$tx" root && rb_checkpoint_validate "$tx" home || return 1
    for role in root home; do
        target=$root/@;index=3
        if [[ $role == home ]];then target=$root/@home;index=4;fi
        if rb_exists "$target";then rb_subvol "$target" || return 1;continue;fi
        target=$root/@;[[ $role == root ]] || target=$root/@home
        for entry in "$tx/new-$role" "$tx"/clone-$role-[0-3];do
            rb_exists "$entry" || continue
            rb_ro "$entry" || continue
            uuid=$(rb_uuid "$entry") || return
            rb_link_valid "$tx" "$tx/created/$role-$uuid" && ! rb_exists "$tx/parked/$role-$uuid" || return 1
            if [[ $entry != "$tx/new-$role" ]];then [[ $(rb_parent "$entry") == "${RB_M[index]}" ]] || return 1;fi
            rb_expose "$tx" "$role" "$entry" "$target" "$root" || return
            printf >&2 'rollback: installed pristine %s fallback; transaction remains unresolved\n' "$role"
            break
        done
        rb_subvol "$target" || { rb_error "no pristine fallback for missing $role; parked data retained";return 1; }
    done
}

rb_finish() {
    local status=$1 root=$2 mounted=$3
    trap - EXIT INT TERM
    if [[ $mounted == true ]]; then
        if ! rb_recover "$root"; then
            printf >&2 'rollback: unresolved recovery retained; mountable roots may still boot\n'
            rb_fallback "$root" || printf >&2 'rollback: required root fallback unavailable; checkpoints retained\n'
            ((status != 0)) || status=1
        fi
        if ! umount "$root"; then printf >&2 'rollback: unmount failed\n'; ((status != 0)) || status=1; fi
    fi
    exit "$status"
}
rollback_btrfs() (
    local root=/btrfs_tmp mounted=false path
    trap 'rb_finish "$?" "$root" "$mounted"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    [[ ! -L $root ]] || exit 1
    mkdir -p -- "$root" || exit
    mount -o subvolid=5 /dev/mapper/cryptroot "$root" || exit
    mounted=true
    rb_recover "$root" || exit
    rb_subvol "$root/@" && rb_subvol "$root/@home" || exit 1
    rb_children "$root/@" && rb_children "$root/@home" || exit 1
    for path in "$root/@old_roots" "$root/@old_home_roots"; do [[ ! -L $path ]] && mkdir -p -- "$path" || exit 1; done
    rb_maintenance "$root" || printf >&2 'rollback: optional maintenance failed\n'
    rb_prepare "$root" || exit
    rb_forward "$root" || exit
    rb_maintenance "$root" || printf >&2 'rollback: optional maintenance failed after commit\n'
)
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then rollback_btrfs; fi
