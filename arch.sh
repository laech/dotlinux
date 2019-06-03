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

read -p "Enter the hostname to place into /etc/hostname for the new system: " host

lsblk -p
ls -l --color /dev/disk/by-id/*

read -e -p "Which disk (not partition) to install to? " disk

[[ ! -e $disk ]] \
    && echo "Error: unknown disk $disk" 1>&2 \
    && exit 1

[[ $disk != /dev/disk/by-id/* ]] \
    && echo "Error: must choose a disk under /dev/disk/by-id/" 1>&2 \
    && exit 1

timedatectl set-ntp true

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

sleep 2

zpool create -f \
      -o ashift=12 \
      -O encryption=on \
      -O keyformat=passphrase \
      -O acltype=posixacl \
      -O xattr=sa \
      -O atime=off \
      -O compression=lz4 \
      -O canmount=off \
      -O mountpoint=none \
      -R /mnt \
      zroot $root_disk

zfs create -o mountpoint=/ zroot/arch
zfs create -o mountpoint=/home zroot/home

zpool set bootfs=zroot/arch zroot

# Import archzfs repo keys
pacman-key --recv-keys F75D9D76
pacman-key --lsign-key F75D9D76

mkfs.fat -F32 "$efi_disk"
mkdir -p /mnt/boot/efi
mount "$efi_disk" /mnt/boot/efi

pacstrap /mnt base

genfstab -U -f /mnt/boot/efi /mnt >> /mnt/etc/fstab

cp "$(dirname ""$0"")"/arch-chroot.sh /mnt/root/
cp "$(dirname ""$0"")"/arch-chroot-zfs-esp-sync.sh /mnt/root/

export host
arch-chroot /mnt /root/arch-chroot.sh
arch-chroot /mnt /root/arch-chroot-zfs-esp-sync.sh
arch-chroot /mnt passwd

rm -v /mnt/root/arch-chroot.sh
rm -v /mnt/root/arch-chroot-zfs-esp-sync.sh
umount -R /mnt
zfs umount -a
zpool export -a
