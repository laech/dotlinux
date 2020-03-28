#!/usr/bin/env bash
#
# System setup within chroot on a fresh install.

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

readonly host=${host:?"hostname not provided"}
readonly username=${username:?"username not provided"}

setup_hostname() {
  echo "$host" >/etc/hostname
}

setup_locale() {
  echo 'LANG=en_US.UTF-8' >/etc/locale.conf

  sed -i \
    's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' \
    /etc/locale.gen &&
    grep '^en_US.UTF-8 UTF-8' /etc/locale.gen >/dev/null

  locale-gen
}

setup_time() {
  ln -sf /usr/share/zoneinfo/Pacific/Auckland /etc/localtime
  hwclock --systohc
}

setup_mirrors() {
  readonly mirrors_url="https://www.archlinux.org/mirrorlist/?country=NZ&country=AU&protocol=https&use_mirror_status=on"
  echo "# $mirrors_url" >/etc/pacman.d/mirrorlist
  curl -s "$mirrors_url" | sed -e 's/^#Server/Server/' -e '/^#/d' >>/etc/pacman.d/mirrorlist
}

setup_zfs() {

  readonly hooks="(base udev autodetect modconf block keyboard zfs filesystems)"
  sed -i \
    "s/^HOOKS=.*/HOOKS=$hooks/g" \
    /etc/mkinitcpio.conf &&
    grep -F "$hooks" /etc/mkinitcpio.conf >/dev/null

  grep -F '[archzfs]' /etc/pacman.conf >/dev/null || echo '
[archzfs]
Server = https://archzfs.com/$repo/$arch
' >>/etc/pacman.conf

  pacman-key --recv-keys F75D9D76
  pacman-key --lsign-key F75D9D76

  readonly installed_linux_version=$(
    pacman -Qi linux |
      grep -i version |
      grep -oP '[^ ]+$'
  )

  readonly zfs_want_linux_version=$(
    pacman -Syi zfs-linux |
      grep -i depends |
      grep -oP 'linux=[^ ]+' |
      sed 's/linux=//'
  )

  if [[ "$installed_linux_version" != "$zfs_want_linux_version" ]]; then
    pacman -S --needed --noconfirm wget
    wget "https://archive.archlinux.org/packages/l/linux/linux-$zfs_want_linux_version-x86_64.pkg.tar.xz"
    wget "https://archive.archlinux.org/packages/l/linux-headers/linux-headers-$zfs_want_linux_version-x86_64.pkg.tar.xz"
    pacman -U --noconfirm "linux-$zfs_want_linux_version-x86_64.pkg.tar.xz" "linux-headers-$zfs_want_linux_version-x86_64.pkg.tar.xz"
  fi

  pacman -S --needed --noconfirm archzfs-linux

  systemctl enable zfs.target
  systemctl enable zfs-mount.service
}

setup_zfs_esp_sync() {
  local depends=
  pacman -S --needed --noconfirm base-devel git sudo

  cd /tmp
  rm -rfv arch-chroot-zfs-esp-sync
  sudo -u nobody git clone https://gitlab.com/lae/arch-zfs-esp-sync.git
  cd arch-zfs-esp-sync

  depends=$(grep -F depends= PKGBUILD | sed 's/depends=(//' | sed 's/)//')
  [[ "$depends" != "" ]] && pacman -S --needed --noconfirm "$depends"
  sudo -u nobody makepkg

  echo '
default=linux
esp_fs=fs0
esp_mount=/boot/efi
' >/etc/zfs-esp-sync

  pacman -U --noconfirm -- *.pkg.tar.xz
  systemctl enable zfs-esp-sync@linux.service
  systemctl start zfs-esp-sync@linux.service
  systemctl enable zfs-esp-sync@linux-lts.service
  systemctl start zfs-esp-sync@linux-lts.service

  zfs-esp-sync linux
}

setup_sudo() {
  pacman -S --needed --noconfirm sudo
  echo '%wheel ALL=(ALL) ALL' >/etc/sudoers.d/wheel
}

setup_user() {
  pacman -S --needed --noconfirm git zsh openssh
  useradd -m -G wheel -s /usr/bin/zsh "$username"
  cat <<EOF | su - "$username"
git clone --bare https://gitlab.com/lae/dotfiles.git "/home/$username/.cfg"
alias config='git --git-dir="/home/$username/.cfg" --work-tree="/home/$username"'
config checkout
config submodule init
config submodule update
EOF
}

disable_root() {
  passwd --lock root
}

setup_hostname
setup_time
setup_locale
setup_mirrors
setup_zfs
setup_zfs_esp_sync
setup_sudo
setup_user
disable_root
