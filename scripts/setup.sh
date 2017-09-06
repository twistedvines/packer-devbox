#!/bin/bash

# install sudo
pacman -S --noconfirm sudo

echo "%wheel      ALL=(ALL) ALL" | tee -a /etc/sudoers.d/wheel > /dev/null
echo "$1        ALL=NOPASSWD: ALL" | tee -a /etc/sudoers.d/wheel > /dev/null

# add my user
groupadd hobag
useradd -m -g hobag -G wheel -s /bin/bash hobag

user_password="$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c16)"
echo "hobag:${user_password}" | chpasswd

# for future script use - must remove when finished!
echo "$user_password" > /tmp/password

mkdir -p "/home/hobag/.config/i3" && chown hobag: "/home/hobag/.config/i3"

# change hostname
sed -i 's/arch-linux/arch-devbox/g' '/etc/hostname'
sed -i 's/arch-linux/arch-devbox/g' '/etc/hosts'
