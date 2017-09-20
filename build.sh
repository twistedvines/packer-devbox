#!/bin/bash

trap tidy_up EXIT

# params

get_opts() {
  while getopts 't:' opt; do
    case "$opt" in
      t)
        VAGRANT_TARGET="$OPTARG"
        ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        ;;
      :)
        echo "Option -$OPTARG requires an argument." >&2
        ;;
    esac
  done
}

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

  local tarball_path="$(echo "$output" | \
    awk -F',' '{print $5}' | \
    grep 'compressed artifacts in:' | \
    awk 'NF>1{print $NF}' | \
    sed "s=\.\/=$(pwd)\/=" | \
    xargs -0 printf "%s"
  )"

  local base_image_name="$(echo "$output" | \
    awk -F',' '{print $5}' | \
    grep -oe "Executing: export [a-zA-Z0-9\-]*" | \
    awk 'NF>1 {print $NF}'
  ).ovf"

  cd "$project_dir"

  echo "{\"password\": \"${password}\",
  \"tarball_path\": \"${tarball_path}\",
  \"base_image_name\": \"${base_image_name}\"}"
}

extract_base_image() {
  local project_dir="$(get_project_dir)"
  local tarball_path="$1"
  tar -xf "$tarball_path" \
    -C "${project_dir}/ovf/"
}

generate_dynamic_build_json() {
  local properties_json="$1"
  local project_dir="$(get_project_dir)"
  local property_keys=$(echo "$properties_json" | jq -r 'keys[]')
  local sed_command=''
  for property_key in ${property_keys}; do
    local value="$(echo "$properties_json" | jq -r ".[\"$property_key\"]")"
    sed_command="$sed_command s=: \"$property_key\"=: \"$value\"=g;"
  done

  sed "$sed_command" "${project_dir}/build.json"
}

build_image() {
  local build_json="$1"
  echo -e "$build_json" | packer build -force -
}

tidy_up() {
  local project_dir="$(get_project_dir)"
  [ -n "$(ls "${project_dir}"/packer-archlinux/build/*)" ] && \
    rm "${project_dir}"/packer-archlinux/build/*
  [ -n "$(ls "${project_dir}/ovf")" ] && rm "${project_dir}"/ovf/*
}

add_vagrant_box() {
  local target_vagrant_project_path="$1"
  local project_dir="$(get_project_dir)"
  local boxfile="$(ls -l "${project_dir}"/build/*.box | head -n 1 | awk '{print $9}')"
  vagrant box add "${boxfile}" --name "arch-linux-devbox" --force
  if [ -d "$target_vagrant_project_path" ]; then
    [ -f "${target_vagrant_project_path}/Vagrantfile" ] && \
      rm "$target_vagrant_project_path/Vagrantfile"
    [ -d "$target_vagrant_project_path}/.vagrant" ] && \
      rm -r "$target_vagrant_project_path/.vagrant"
  else
    mkdir -p "$target_vagrant_project_path"
  fi
  cd "$target_vagrant_project_path" && vagrant init arch-linux-devbox > /dev/null
}

get_opts "$@"
echo 'initialising base image repository...'
initialise_base_image_submodule
exec 5>&1
echo 'building base image...'
BASE_BUILD_PROPERTIES="$(build_base_image | tee >(cat - >&5))"
BASE_BUILD_PROPERTIES="$(echo "$BASE_BUILD_PROPERTIES" | jq '.')"
echo 'extracting base image...'
extract_base_image "$(echo "$BASE_BUILD_PROPERTIES" | jq -r '.["tarball_path"]')"
echo 'building build json...'
BUILD_JSON="$(generate_dynamic_build_json "$BASE_BUILD_PROPERTIES")"
echo 'building dev box...'
build_image "$BUILD_JSON" >(cat - >&5)
exec 5<&-
echo 'tidying up...'
tidy_up
if [ -n "$VAGRANT_TARGET" ]; then
  echo 'adding vagrant box...'
  add_vagrant_box "$HOME/dev/vagrant/twistedvines/arch-devbox"
fi
