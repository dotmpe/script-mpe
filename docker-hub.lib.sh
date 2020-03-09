#!/bin/sh

docker_hub_tags() # Ns/Name
{
  docker_hub_tags_raw "$@" |
    sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' |
    tr '}' '\n'  |
    awk -F: '{print $3}'
}
docker_hub_tags_raw()
{
  web_fetch https://registry.hub.docker.com/v1/repositories/$1/tags
}


# List tags with digests for images. Multiple digests for one tag may be
# present, even for one architecture.
docker_hub_tag_digests() # Image-Name [Architecture]
{
  # TODO: use 'next' attribute to fetch multiple pages of tags
  docker_hub_tag_digests_raw "$@" | {
      test -z "$2" && {
        jq -r '.results[] | .name, ( .images[] | " "+.architecture+" "+.digest )' || return
      } || {
        jq -r '.results[] | .name, ( .images[] | select(.architecture=="'"$2"'") | " "+.architecture+" "+.digest )'
      }
    }
}
docker_hub_tag_digests_raw() # Image-Name [Architecture]
{
  web_fetch https://registry.hub.docker.com/v2/repositories/$1/tags
}

#
