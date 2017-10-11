#!/bin/bash

# This script tidies up after the installation process.

# revoke hobag's nopasswd group membership
gpasswd -d hobag nopasswd

# add hobag to wheel group for password sudo
usermod -a -G wheel hobag
