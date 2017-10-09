#!/bin/bash

# install sudo
pacman -S --noconfirm sudo

echo "%wheel      ALL=(ALL) ALL" | tee -a /etc/sudoers.d/wheel > /dev/null

# add my user
groupadd hobag

# add the src group for access to /usr/local/src
groupadd src

chown -R ':src' '/usr/local/src'
chmod 0775 '/usr/local/src'

useradd -m -g hobag -G wheel,src -s /bin/bash hobag

user_password="$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c16)"
echo "hobag:${user_password}" | chpasswd
echo "hobag's temporary password: ${user_password}"

mkdir -p "/home/hobag/.config/i3" && chown hobag: "/home/hobag/.config/i3"

# change hostname
sed -i 's/arch-linux/arch-devbox/g' '/etc/hostname'
sed -i 's/arch-linux/arch-devbox/g' '/etc/hosts'
