#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

readonly host=${host:?"hostname not provided"}

echo "$host" > /etc/hostname

echo 'LANG=en_US.UTF-8' > /etc/locale.conf

sed -i \
    's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' \
    /etc/locale.gen \
    && \
    grep '^en_US.UTF-8 UTF-8' /etc/locale.gen > /dev/null

readonly hooks="(base udev autodetect modconf block keyboard zfs filesystems)"
sed -i \
    "s/^HOOKS=.*/HOOKS=$hooks/g" \
    /etc/mkinitcpio.conf \
    && \
    grep -F "$hooks" /etc/mkinitcpio.conf > /dev/null

ln -sf /usr/share/zoneinfo/Pacific/Auckland /etc/localtime

hwclock --systohc

locale-gen

grep -F '[archzfs]' /etc/pacman.conf > /dev/null || echo '
[archzfs]
Server = https://archzfs.com/$repo/$arch
' >> /etc/pacman.conf

pacman-key --recv-keys F75D9D76
pacman-key --lsign-key F75D9D76

readonly installed_linux_version=$(
    pacman -Qi linux \
        | grep -i version \
        | grep -oP '[^ ]+$')

readonly zfs_want_linux_version=$(
    pacman -Syi zfs-linux \
        | grep -i depends \
        | grep -oP 'linux=[^ ]+' \
        | sed 's/linux=//')

if [[ "$installed_linux_version" != "$zfs_want_linux_version" ]]; then
    pacman -S --needed --noconfirm wget
    wget "https://archive.archlinux.org/packages/l/linux/linux-$zfs_want_linux_version-x86_64.pkg.tar.xz"
    pacman -U --noconfirm "linux-$zfs_want_linux_version-x86_64.pkg.tar.xz"
fi

pacman -S --needed --noconfirm archzfs-linux
