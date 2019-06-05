#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

readonly username=${username:?"username not provided"}

pacman -S --needed --noconfirm git zsh openssh

useradd -m -s /usr/bin/zsh "$username"

cat <<EOF | su - "$username"
git clone --bare https://gitlab.com/lae/dotfiles.git "/home/$username/.cfg"
alias config='git --git-dir="/home/$username/.cfg" --work-tree="/home/$username"'
config config --local status.showUntrackedFiles no
config checkout
EOF
