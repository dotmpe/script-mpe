# TODO: cleanup
script_mpe_part_fun_user_load ()
{
: source script-mpe:tool/sh/part/fun-user.sh
  . "${US_BIN:?}"/tool/sh/part/fun-user.sh
}

user_fun ()
{
: source script-mpe:tool/sh/part/fun-user.sh

  declare -ga \
    user_{{script,desktop}_,}dirs \
    local_meta_dirs

  user_script_dirs=(
    ~/{.conf,bin,.l/c,htdocs,project/{user-conf,user-scripts{,-incubator}}}
  )
  user_desktop_dirs=(
    ~/{Desktop,Documents,Downloads,Music,Pictures,Videos}
  )
  user_dirs=(
    "${user_script_dirs[@]}"
    "${user_desktop_dirs[@]}"
  )
  local_meta_dirs=(
    .meta/build
    .meta/cache
    .meta/stat/index
    .meta/stat/cache
    .meta/log
  )

  _NOTICE "Checking user function env node state"

  local usrdir metadir
  for usrdir in "${user_dirs[@]:?}"
  do
    for metadir in "${local_meta_dirs[@]:?}"
    do
      [[ -e "${usrdir:?}/${metadir:?}" ]] || >&2 mkdir -vp "${usrdir:?}/${metadir:?}"
    done
  done

  _NOTICE "User function env node initialized"
}

# Id: us-bin:tool/sh/part/fun-user.sh              vim:set ft=sh sw=2 sts=2 et:
