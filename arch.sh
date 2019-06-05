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

read -r -p "Enter the username to be created in the new system: " username
read -r -p "Enter the hostname to place into /etc/hostname in the new system: " host

lsblk -p
ls -l --color /dev/disk/by-id/*

read -r -e -p "Which disk (not partition) to install to? " disk

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
      zroot "$root_disk"

zfs create -o mountpoint=/ zroot/arch
zfs create -o mountpoint=/home zroot/home

zpool set bootfs=zroot/arch zroot

mkfs.fat -F32 "$efi_disk"
mkdir -p /mnt/boot/efi
mount "$efi_disk" /mnt/boot/efi

readonly mirrors_url="https://www.archlinux.org/mirrorlist/?country=NZ&country=AU&protocol=https&use_mirror_status=on"
echo "# $mirrors_url" > /etc/pacman.d/mirrorlist
curl -s "$mirrors_url" | sed -e 's/^#Server/Server/' -e '/^#/d' >> /etc/pacman.d/mirrorlist

pacstrap /mnt base

genfstab -U -f /mnt/boot/efi /mnt >> /mnt/etc/fstab

cp "$(dirname "$0")"/*.sh /mnt/root/

export host
export username
arch-chroot /mnt /root/arch-chroot.sh
arch-chroot /mnt /root/arch-chroot-zfs-esp-sync.sh
arch-chroot /mnt /root/arch-chroot-dotfiles.sh
arch-chroot /mnt passwd
arch-chroot /mnt passwd "$username"

rm -v /mnt/root/arch-chroot.sh
rm -v /mnt/root/arch-chroot-zfs-esp-sync.sh
umount -R /mnt
zfs umount -a
zpool export -a
