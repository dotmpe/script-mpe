
# Lib

# Get project/running container context
docker_sh_p_ctx()
{
  docker_sh_arg_psh $1 defaults
  test -e "$HOME/project/$1/package.yml" || return
  req_proj_meta
  jsotk_package_sh_defaults $proj_meta  > $psh
}

docker_sh_p_arg()
{
  test -n "$1" || set -- '*'
  set -- "$(normalize_relative "$go_to_before/$1")"
  docker_sh_p_arg "$@"
}


req_proj_meta()
{
  test -n "$proj_meta" || proj_meta="$(echo $HOME/project/$1/package.y*ml | cut -d' ' -f1)"
  test -e "$proj_meta" || error "no checkout $1" 1
}

# replace with docker_sh_p_ctx
# Find container ID for name, or image-name (+tag)
docker_sh_c()
{
  test -n "$ps_f"|| ps_f=-a
  test -n "$2" && {
    local name="$2" tag=
    test -z "$3" || name=$2:$3
    docker_sh_c=$(${sudo}docker ps $ps_f --format='{{.ID}} {{.Image}}' |
        grep '\ '$name'$' | cut -f1 -d' ')
  } || {
    req_vars docker_name
    docker_sh_c=$(${sudo}docker ps $ps_f --format='{{.ID}} {{.Names}}' |
        grep '\ '$docker_name'$' | cut -f1 -d' ')
  }
  test -n "$docker_sh_c" || return 1
}

# Return true if running
docker_sh_p()
{
  ${sudo}docker ps | grep -q '\<'$docker_name'\>' || return 1
}

docker_sh_load_psh()
{
  local psh=
  docker_sh_arg_psh "$1" "$2" || return $?
  test -e "$psh" || error "no dckr $2 registered for $1" 1
  cd ~/project/$1 || error "no dir for $1" 1
  . $psh || return $?
}

docker_sh_arg_psh()
{
  test -n "$1" || error "project name expected" 1
  psh=$UCONF/dckr/$1/$2.sh
  mkdir -vp $(dirname $psh)
}

docker_sh_script_from()
{
  local psh; docker_sh_arg_psh "$@" || return 4?
  req_vars proj_meta psh
  test $proj_meta -ot $psh || {
    docker_sh_package_cmd_f_to_sh $proj_meta $2 > $psh
    log "Regenerated $psh"
  }
}

req_vars()
{
  local v=
  while test $# -gt 0
  do
    v="$(eval echo \$$1)"
    test -n "$v" || error $1 $?
  done
}

docker_sh_package_cmd_f_to_sh()
{
  test -n "$1" || set -- package.yaml
  test -n "$2" || set -- "$1" run
  jsotk_package_sh_defaults $1
  echo "docker_sh_${2}_f=\\"
  jsotk.py -I yaml -O fkv objectpath $1 '$..*[@.dckr.'$2'_f]' \
    | grep -v '^\s*$' | sed 's/^__[0-9]*="/    /' | sed 's/"$/ \\/g'
  echo "    \$docker_sh_${2}_f"
}




# include private projects
test ! -e $DCKR_UCONF/local.sh || {
  . $DCKR_UCONF/local.sh
}





# Docker

docker_sh_man_1_redock=\
'
  If container is running, leave image unless forced. Otherwise delete
  for rebuild. Then build and run image. Finish with ps line and IP address.
'
docker_sh_spc_redock='redock <image-name> <dckr-name> [<tag>=latest]'
docker_sh_redock()
{
  local reset= image_name= docker_name= tag=

  docker_sh_rebuild "$@"

  # Run if needed and stat
  ${sudo}docker ps -a | grep -q '\<'$docker_name'\>' && {
    test -z "$reset" || error "still running? $docker_name" 3
  } || {
    ${sudo}docker run -dt --name $docker_name \
      $image_name:${tag}
  }

  echo "$docker_name proc: "
  ${sudo}docker ps -a | grep '\<'$docker_name'\>'
  docker-sh.sh ip $docker_name
}

docker_sh_rebuild()
{
  test -z "$choice_force" || reset=1
  # TODO: rebuild
}

docker_sh_build()
{
  test -n "$image_name" || error "$image_name" $?
  test -n "$docker_shfile_dir" || docker_shfile_dir=.
  ${sudo}docker build -t $image_name $docker_sh_build_f $docker_shfile_dir || return $?
  return $?
}

docker_sh_run()
{
  # default flags: start daemon w/ tty
  test -n "$docker_sh_f" || docker_sh_f=-dt

  # pass container env script if set, or exists in default location
  test -n "$docker_sh_env" || docker_sh_env=$DCKR_UCONF/$docker_name-env.sh
  test -e "$docker_sh_env" && \
    docker_sh_f="$docker_sh_f --env-file $docker_sh_env"
  test -e "$proj_dir/env.sh" && \
    docker_sh_f="$docker_sh_f --env-file $proj_dir/env.sh"

  # pass hostname if set
  test -z "$docker_sh_hostname" || \
    docker_sh_f="$docker_sh_f --hostname $docker_sh_hostname"

  test -n "$docker_name" || error docker_name 1

  ${sudo}docker run $docker_sh_f $@ \
    --name $docker_name \
    --env DCKR_NAME=$docker_name \
    --env DCKR_IMAGE=$image_name \
    --env DCKR_CMD="$docker_cmd" \
    $docker_sh_argv \
    $image_name \
    $docker_cmd

  return $?
}

docker_sh_start()
{
  req_vars docker_sh_c
  echo "Startng container $docker_sh_c:"
  ${sudo}docker start $docker_sh_c || return $?
}

docker_sh_stop()
{
  test -n "$docker_sh_c" && {
    std_info "Stopping container $docker_sh_c:"
    ${sudo}docker stop $docker_sh_c
    return
  }
  test -z "$docker_name" && {
    test -z "$image_name" || {
      std_info "Looking for running container by image-name $image_name:"
      docker_sh_c
      std_info "Stopping container by image-name $image_name:"
      ${sudo}docker stop $docker_sh_c
    }
  } || {
    # check for container with name and remove
    ${sudo}docker ps | grep -q '\<'$docker_name'\>' && {
      std_info "Stopping container by container-name $docker_name:"
      ${sudo}docker stop $docker_name
    } || true
  }
}

# remove container (with name or for image-name)
docker_sh_rm()
{
  test -n "$docker_sh_c" && {
    note "Removing container $docker_sh_c:"
    ${sudo}docker rm $docker_sh_c
    return
  }
  test -z "$docker_name" && {
    test -z "$image_name" || {
      debug "Looking for container by image-name $image_name:"
      docker_sh_c -a
      std_info "Removing container $docker_sh_c"
      ${sudo}docker rm $docker_sh_c
    }
  } || {
    # check for container with name and remove
    ${sudo}docker ps -a | grep -q '\<'$docker_name'\>' && {
      std_info "Removing container by container-name $docker_name:"
      ${sudo}docker rm $docker_name
    } || true
  }
}

# gobble up flags and set $docker_sh_f, and/or set and return $docker_cmd upon first arg.
# $c is the amount of arguments consumed
docker_sh_f_argv()
{
  c=0
  while test $# -gt 0
  do
    test -z "$1" || {
      test "${1:0:1}" = "-" && {
        docker_sh_f="$docker_sh_f $1"
      } || {
        docker_cmd="$1"
        c=$(( $c + 1 ))
        return
      }
    }
    c=$(( $c + 1 )) && shift 1
  done
}

docker_sh_name_argv()
{
  test -z "$1" && {
    # dont override without CLI args, only set
    test -n "$docker_name" && return 1;
  }
  test -z "$1" && name=$(basename $(pwd)) || name=$1
  docker_name=${pref}${name}
  test -n "$1" || std_info "Using dir for dckr-name: $docker_name"
}

docker_sh_image_argv()
{
  test -z "$1" && error "Must enter image name or tag" 1 || tag=$1
  c=1
  image_name=${tag}
}


