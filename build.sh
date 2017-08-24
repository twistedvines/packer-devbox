#!/bin/bash

get_project_dir() {
  local filepath="$(dirname $0)"
  cd $filepath
  pwd
}

initialise_base_image_submodule() {
  cd "$(get_project_dir)"
  local submodule_status="$(git submodule status \
    | grep packer-archlinux \
    | head -c1
  )"
  if [ -z "$submodule_status" ]; then
    git submodule init && git submodule update
  fi
  git submodule update --remote
}

build_base_image() {
  # duplicate stdout so we can see what's happening
  local project_dir="$(get_project_dir)"
  cd "$project_dir/packer-archlinux"
  local output="$(packer build -force -machine-readable build.json | \
    tee >(cat - | awk -F',' '{print $5}' >&5))"

  local password="$(echo "$output" | \
    awk -F',' '{print $5}' | \
    grep 'root password for new build is' | \
    awk 'NF>1{print $NF}' | \
    xargs -0 printf "%s"
    )"

  cd "$project_dir"

  echo "$password"
}

extract_base_image() {
  local project_dir="$(get_project_dir)"
  tar -xf "${project_dir}/packer-archlinux/build/arch-linux.tar.gz" \
    -C "${project_dir}/ovf/"
}

generate_dynamic_build_json() {
  local password="$(echo "$1" | sed 's/\//\\\//g')"
  sed "s/\"password\"/\"$password\"/g" "$(get_project_dir)/build.json"
}

build_image() {
  local build_json="$1"
  echo -e "$build_json" | packer build -force -
}

tidy_up() {
  local project_dir="$(get_project_dir)"
  rm "${project_dir}"/packer-archlinux/build/*
  rm "${project_dir}"/ovf/*
}

echo 'initialising base image repository...'
initialise_base_image_submodule
exec 5>&1
echo 'building base image...'
PASSWORD="$(build_base_image | tee >(cat - >&5))"
echo 'extracting base image...'
extract_base_image
echo 'building build json...'
BUILD_JSON="$(generate_dynamic_build_json $PASSWORD)"
echo 'building dev box...'
build_image "$BUILD_JSON" >(cat - >&5)
exec 5<&-
echo 'tidying up...'
tidy_up
