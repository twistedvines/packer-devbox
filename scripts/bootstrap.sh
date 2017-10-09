#!/bin/bash

# this script pulls down a repository and filters it thru git archive
# in order to remove git-related files.

set -e

install_repository() {
  local repository_url="$1"
  local repository_name="$(basename "$repository_url" | sed 's/\.git//')"
  local destination="${2}/${repository_name}"

  mkdir -p "$destination"
  git clone "$repository_url" "/usr/local/src/${repository_name}"
  cd "/usr/local/src/${repository_name}" && git archive master | tar -x -C "$destination"
}

bootstrap() {
  local user="$1"
  local path_to_repo="$2"
  su "$user" -c "cd \"$path_to_repo\" && ./install.sh 'arch'"
}

install_repository 'https://github.com/twistedvines/bootstrap.git' '/tmp/'
bootstrap 'hobag' '/tmp/bootstrap'
