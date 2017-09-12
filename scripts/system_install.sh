#!/bin/bash

# this script is for installing additional extras on top of the original base image.

set -e

install_xorg() {
  pacman -S --noconfirm xorg-server xorg-xinit xterm xorg-xrandr
}

install_xorg
