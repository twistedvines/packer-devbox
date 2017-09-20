#!/bin/bash

# basic .bash_profile. Runs on spawn of login shell.

if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
  exec startx
else
  [ -f ~/.bashrc ] && source ~/.bashrc
fi
