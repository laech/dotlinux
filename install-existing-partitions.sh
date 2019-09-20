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

replace_efi_boot=${replace_efi_boot:-""}
[[ "$replace_efi_boot" == "" ]] \
    && read -r -p "Replace EFI/boot entry with EFI shell? [yes/no] " replace_efi_boot

[[ "$replace_efi_boot" != "yes" ]] \
    && [[ "$replace_efi_boot" != "no" ]] \
    && echo "unknown value for replace_efi_boot: $replace_efi_boot" \
    && exit 1

read -r -p "Enter the username to be created in the new system: " username
read -r -p "Enter the hostname to place into /etc/hostname in the new system: " host

lsblk -p
ls -l --color /dev/disk/by-id/*


efi_disk=${efi_disk:-""}
[[ "$efi_disk" == "" ]] \
    && read -r -e -p "Which disk for the EFI parition? " efi_disk

[[ ! -e $efi_disk ]] \
    && echo "Error: unknown disk $efi_disk" 1>&2 \
    && exit 1

[[ $efi_disk != /dev/disk/by-id/* ]] \
    && echo "Error: must choose a disk under /dev/disk/by-id/" 1>&2 \
    && exit 1


root_disk=${root_disk:-""}
[[ "$root_disk" == "" ]] \
    && read -r -e -p "Which disk for the root partition? " root_disk

[[ ! -e $root_disk ]] \
    && echo "Error: unknown disk $root_disk" 1>&2 \
    && exit 1

[[ $root_disk != /dev/disk/by-id/* ]] \
    && echo "Error: must choose a disk under /dev/disk/by-id/" 1>&2 \
    && exit 1


timedatectl set-ntp true

umount -R /mnt || true
zfs umount -a
zpool export -a

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

export host
export username
cp "$(dirname "$0")"/*.sh /mnt/root/
arch-chroot /mnt /root/arch-chroot.sh
arch-chroot /mnt passwd "$username"

if [[ "$replace_efi_boot" == "yes" ]]; then
    mkdir -p /mnt/boot/efi/EFI/boot
    cp "$(dirname "$0")"/shellx64_v1.efi /mnt/boot/efi/EFI/boot/bootx64.efi
fi

rm -v /mnt/root/*.sh
umount -R /mnt
zfs umount -a
zpool export -a
