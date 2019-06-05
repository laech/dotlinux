#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

pacman -S --needed --noconfirm base-devel git sudo

cd /tmp
rm -rfv arch-chroot-zfs-esp-sync
sudo -u nobody git clone https://gitlab.com/lae/arch-zfs-esp-sync.git
cd arch-zfs-esp-sync

sudo -u nobody makepkg

echo '
targets=(linux-lts linux)
esp_fs=fs0
esp_mount=/boot/efi
' > /etc/zfs-esp-sync
pacman -U --noconfirm -- *.pkg.tar.xz
