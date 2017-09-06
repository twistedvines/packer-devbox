#!/bin/bash

# this script is used to tidy up artifacts left over from the build process.

echo "${1}'s ephemeral password: $(cat /tmp/password)"
rm /tmp/password

sed -i "s/${1}.*//g" '/etc/sudoers.d/wheel'
