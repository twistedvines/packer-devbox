#!/bin/bash

trap tidy_up EXIT

# params

get_opts() {
  while getopts 't:s' opt; do
    case "$opt" in
      t)
        VAGRANT_TARGET="$OPTARG"
        ;;
      s)
        SPIN_UP=true
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
  if [[ "$0" == '-bash' ]]; then
    pwd
  else
    local filepath="$(dirname $0)"
    cd $filepath
    pwd
  fi
}

initialise_submodules() {
  cd "$(get_project_dir)"
  local submodule_result="$(git submodule update --init --recursive --remote)"

  if [ -n "$submodule_result" ]; then
    local submodules="$(cat "$(get_project_dir)/.gitmodules" | grep path \
      | awk -F'=' '{print $NF}')"

    for submodule in $submodules; do
      git add "$submodule"
    done

    git commit -m "$(printf %b "Updated submodules\n\n$submodules")"
  fi
}

build_base_image() {
  # duplicate stdout so we can see what's happening
  local project_dir="$(get_project_dir)"
  cd "$project_dir/packer-archlinux"
  local output="$(./build.sh -p compress | tee >(cat - >&5))"

  local password="$(echo "$output" | \
    grep 'root password for new build is' | \
    awk 'NF>1{print $NF}' | \
    xargs -0 printf "%s"
  )"

  local tarball_path="$(echo "$output" | \
    grep 'compressed artifacts in:' | \
    awk 'NF>1{print $NF}' | \
    sed "s=\.\/=$(pwd)\/=" | \
    xargs -0 printf "%s"
  )"

  local base_image_name="$(echo "$output" | \
    grep -oe "Executing: export [a-zA-Z0-9\-]*" | \
    awk 'NF>1 {print $NF}'
  ).ovf"

  cd "$project_dir"

  echo "{\"ssh_password\": \"${password}\",
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
  local project_dir="$(get_project_dir)"

  local build_json="$(cat "${project_dir}/build.json" | \
    jq ".variables = .variables * $1")"

  local environment_variables="$(echo "$2" | sed -e 's/"//g')"

  local env_var_array='[]'
  for env_var in $environment_variables; do
    env_var_array="$(echo "$env_var_array" | jq ".+ [\"$env_var\"]")"
  done

  echo "$build_json" | jq ".provisioners = [.provisioners[] |"`
    `"select(.type == \"shell\").environment_vars = $env_var_array]"
}

build_image() {
  local build_json="$1"
  echo -e "$build_json" | packer build -force -
}

tidy_up() {
  local project_dir="$(get_project_dir)"
  rm "${project_dir}"/packer-archlinux/build/* 2> /dev/null
  rm "${project_dir}"/ovf/* 2> /dev/null
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
  cd "$target_vagrant_project_path" && \
    vagrant init arch-linux-devbox > /dev/null
}

spin_up_vagrant_box() {
  local target_vagrant_project_path="$1"
  cd "$target_vagrant_project_path"
  vagrant destroy -f && vagrant up
}

get_environment_variables() {
  local environment=
  [ -f "$(get_project_dir)/.env" ] && \
    environment="$(cat "$(get_project_dir)/.env")"

  [ -f "$(get_project_dir)/.env.local" ] && \
    environment="$(printf \
    "${environment}\n$(cat "$(get_project_dir)/.env.local")")"

  local env_var_names="$(echo "$environment" | \
    awk -F'=' '{print $1}' | sort | uniq)"

  local uniq_env
  for env_var_name in $env_var_names; do
    uniq_env="$(printf "$uniq_env\n"`
      `"$(printf "$environment" | grep "$env_var_name" | tail -n1)")"
  done

  echo -e "$uniq_env"
}

get_opts "$@"

if [[ "$0" != '-bash' ]]; then
  echo 'initialising submodules...'
  initialise_submodules
  exec 5>&1
  echo 'building base image...'
  BASE_BUILD_PROPERTIES="$(build_base_image | tee >(cat - >&5))"
  BASE_BUILD_PROPERTIES="$(echo "$BASE_BUILD_PROPERTIES" | jq '.')"
  echo 'extracting base image...'
  extract_base_image "$(echo "$BASE_BUILD_PROPERTIES" | jq -r '.["tarball_path"]')"
  echo 'building build json...'
  environment_variables="$(get_environment_variables)"
  BUILD_JSON="$(generate_dynamic_build_json \
    "$BASE_BUILD_PROPERTIES" "$environment_variables")"

  echo 'building dev box...'
  build_image "$BUILD_JSON" >(cat - >&5)
  exec 5<&-
  if [ -n "$VAGRANT_TARGET" ]; then
    echo 'adding vagrant box...'
    add_vagrant_box "$VAGRANT_TARGET"

    if [ -n "$SPIN_UP" ]; then
      echo 'spinning-up newly created vagrant box...'
      spin_up_vagrant_box "$VAGRANT_TARGET"
    fi
  fi
  echo 'tidying up...'
  tidy_up
fi
