#!/bin/sh

docker_sh_lib_load()
{
  test -n "$dckr_pref" || dckr_pref=
  test -n "$docker_sh_c" || docker_sh_c=
  test -n "$docker_sh_c_port" || docker_sh_c_port=22
  test -n "$docker_name" || docker_name=
  test -n "$docker_image" || docker_image=
}

docker_sh_names()
{
  ${dckr_pref}docker inspect --format='{{.Name}}' $(${dckr_pref}docker ps -aq --no-trunc)
}

# Default to env container
docker_sh_c() # CMD [Container] [ARGS...]
{
  local c="$2" act="$1"
  test $# -gt 1 && shift 2 || shift 1
  test -n "$c" || c=$docker_sh_c
  test -n "$c" || c=$docker_name
  docker_sh_c_$act "$c" "$@"
}

docker_sh_c_exists() # [Container]
{
  docker_sh_c_status "$@" >/dev/null
}
docker_sh_c_status() # [Container]
{
  docker_sh_c_inspect '{{.State.Status}}' "$@"
}

docker_sh_c_ip() # [Container]
{
  test -n "$1" || set -- $docker_sh_c
  test -n "$1" || set -- $docker_name
  test -n "$1" || error "dckr-ip: container required" 1
  ${dckr_pref}docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1 ||
    error "docker IP inspect on $1 failed" 1
}

docker_sh_c_port()
{
  test -n "$1" || set -- $docker_sh_c
  test -n "$1" || set -- $docker_name
  test -n "$1" || error "dckr-ip: container required" 1
  test -n "$2" || set -- "$1" $docker_sh_c_port
  ${dckr_pref}docker inspect --format '{{ (index (index .NetworkSettings.Ports "'$2'/tcp") 0).HostPort }}' "$1" || error "docker port $2 inspect on $1 failed" 1
}

docker_sh_c_inspect() # Expr [Container]
{
  test -n "$2" || set -- "$1" $docker_sh_c
  test -n "$2" || set -- "$1" $docker_name
  docker --inspect "$1" "$2"
}

docker_sh_c_image_name() # [Container]
{
  docker_sh_c_inspect '{{.Config.Image}}' "$@"
}

