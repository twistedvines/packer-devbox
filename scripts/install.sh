#!/bin/bash

# this script is for installing additional extras on top of the original base image.

install_window_manager() {
  pacman -S --noconfirm xorg-server xorg-xinit xterm xorg-xrandr
  pacman -S --noconfirm i3
}

install_window_manager
