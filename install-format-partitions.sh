#!/usr/bin/env bash

# https://github.com/zfsonlinux/zfs/wiki/Debian-Stretch-Root-on-ZFS
# https://wiki.archlinux.org/index.php/Installing_Arch_Linux_on_ZFS
# https://wiki.archlinux.org/index.php/Installation_guide
# https://gitlab.com/lae/arch-zfs-iso
# https://gitlab.com/lae/arch-zfs-esp-sync

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

[[ $EUID != 0 ]] \
    && echo "Error: need to run as root." 1>&2 \
    && exit 1

modprobe zfs

lsblk -p
ls -l --color /dev/disk/by-id/*

read -r -e -p "Which disk (not partition) to install to? " disk

[[ ! -e $disk ]] \
    && echo "Error: unknown disk $disk" 1>&2 \
    && exit 1

[[ $disk != /dev/disk/by-id/* ]] \
    && echo "Error: must choose a disk under /dev/disk/by-id/" 1>&2 \
    && exit 1

umount -R /mnt || true
zfs umount -a
zpool export -a

readonly efi_partnum=1
readonly root_partnum=2

sgdisk --zap-all "$disk"
sgdisk --new=$efi_partnum:0:+512M --typecode=$efi_partnum:EF00 "$disk"
sgdisk --largest-new=$root_partnum --typecode=$root_partnum:BF01 "$disk"

readonly efi_disk="$disk-part$efi_partnum"
readonly root_disk="$disk-part$root_partnum"

while [[ ! -e "$efi_disk" ]]; do sleep 1; done
while [[ ! -e "$root_disk" ]]; do sleep 1; done

export efi_disk
export root_disk
"$(dirname "$0")"/install.sh
