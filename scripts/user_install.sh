#!/bin/bash

# this script is for installing additional user-specific extras.

install_window_manager() {
  pacman -S --noconfirm i3
}

install_dependencies() {
  pacman -S --noconfirm pkg-config fakeroot git
}

install_yaourt() {
  local user="$1"
  local password="$2"

  mkdir /tmp/yaourt_install
  git clone https://aur.archlinux.org/package-query.git \
    /tmp/yaourt_install/package-query
  git clone https://aur.archlinux.org/yaourt.git \
    /tmp/yaourt_install/yaourt

  chown -R "${user}:" /tmp/yaourt_install

  su "$user" -c "cd /tmp/yaourt_install/package-query && makepkg --noconfirm -si"
  su "$user" -c "cd /tmp/yaourt_install/yaourt && makepkg --noconfirm -si"
}

install_desktop_manager() {
  local user="$1"
  su "$user" -c "yaourt --noconfirm -S cdm-git"
}

install_window_manager
install_dependencies
install_yaourt "$1" "$(cat /tmp/password)"
install_desktop_manager "$1"
