#!/bin/bash

create_keypair_as_user() {
  local user="$1"
  su "$user" -l -c 'ssh-keygen -t rsa -b 4096 -f "${HOME}/.ssh/id_rsa" -N ""'
}

install_jq() {
  pacman -S --noconfirm jq
}

remove_public_key_from_github_if_exists() {
  local keys="$(curl -s -XGET -H "Authorization: Bearer $GITHUB_OAUTH_TOKEN" \
    'https://api.github.com/user/keys')"

  local id="$(echo "$keys" | jq -r \
    ".[] | select(.title | contains(\"$GITHUB_KEY_NAME\")) | .id")"

  if [ -n "$id" ]; then
    curl -s -XDELETE -H "Authorization: Bearer $GITHUB_OAUTH_TOKEN" \
      "https://api.github.com/user/keys/$id"
  fi
}

update_public_key_on_github() {
  local user="$1"
  local public_key="$(su "$user" -l -c 'cat "${HOME}/.ssh/id_rsa.pub"')"

  local json="{\"title\": \"$GITHUB_KEY_NAME\","`
    `"\"key\": \"$public_key\"}"

  curl -s -XPOST -H "Authorization: Bearer $GITHUB_OAUTH_TOKEN" \
    -d "$json" 'https://api.github.com/user/keys'
}

# install sudo
pacman -S --noconfirm sudo

echo "%wheel      ALL=(ALL) ALL" | tee -a /etc/sudoers.d/wheel > /dev/null

# add my user
groupadd hobag

# add the src group for access to /usr/local/src
groupadd src

chown -R ':src' '/usr/local/src'
chmod 0775 '/usr/local/src'

useradd -m -g hobag -G src,nopasswd -s /bin/bash hobag

user_password="$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c16)"
echo "hobag:${user_password}" | chpasswd
echo "hobag's temporary password: ${user_password}"

# change hostname
sed -i 's/arch-linux/arch-devbox/g' '/etc/hostname'
sed -i 's/arch-linux/arch-devbox/g' '/etc/hosts'

install_jq
create_keypair_as_user 'hobag'
remove_public_key_from_github_if_exists
update_public_key_on_github 'hobag'
