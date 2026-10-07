#!/bin/sh

docker_hub_lib__load()
{
  lib_require web
}

docker_hub_tags() # Ns/Name
{
  test $# -eq 1 || return
  docker_hub_tags_raw "$@" |
    sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' |
    tr '}' '\n'  |
    awk -F: '{print $3}'
}
docker_hub_tags_raw()
{
  test $# -eq 1 || return
  web_fetch https://registry.hub.docker.com/v1/repositories/$1/tags
}


# List tags with digests for images. Multiple digests for one tag may be
# present, even for one architecture.
docker_hub_tag_digests() # Image-Name [Architecture]
{
  test $# -ge 1 -a $# -le 2 || return
  docker_hub_tag_digests_raw "$@" | jq -s 'add' | {
      test -z "${2-}" && {
        jq -r '.[] | .name, ( .images[] | " "+.architecture+" "+.digest )' || return
      } || {
        jq -r '.[] | .name, ( .images[] | select(.architecture=="'"$2"'") | " "+.architecture+" "+.digest )'
      }
    }
}
docker_hub_tag_digests_raw() # Image-Name [Architecture]
{
  test $# -eq 1 || return
  docker_hub_registry_allpages "v2/repositories/$1/tags?page=2"
}


docker_hub_registry_allpages()
{
  test $# -eq 1 || return
  { fnmatch "https://*" "$1" && {
      web_fetch "$1"
      return $?
  } || {
      web_fetch "https://registry.hub.docker.com/$1"
      return $?
  }; } | jq -cr '.next, .results' - | {
      read next
      cat -
      test "null" != "$next" || return 0
      docker_hub_registry_allpages "$next"
  }
}

#
