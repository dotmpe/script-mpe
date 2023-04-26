#!/bin/sh


meta_sh_attributes ()
{
  meta_attributes "$@"
}

meta_sh_attributes_sh ()
{
  meta_attributes_sh "$@"
}

meta_sh_context () # ~ [ <Paths...> ] # List attributes at paths and parents
{
  test $# -gt 0 ||
      eval "set -- ${meta_sh_default_leafs:-"\{.,\{main,index,default}.*}"}"

  declare -A metapaths

  local attr path
  while test $# -gt 0
  do
    path=$(realpath -s "$1")
    attr=$(meta_attributes "$path")
    test -z "$attr" ||
        metapaths[$path]=$attr
    while test "$path" != /
    do
      path=$(dirname "$path")
      test -n "${metapaths[$path]-unset}" || continue
      attr=$(meta_attributes "$path") || true
      metapaths[$path]=$attr
    done
    shift
  done

  for path in $(foreach "${!metapaths[@]}" | sort )
  do
    attr="${metapaths[$path]:-}"
    test -n "$attr" || continue
    echo "$path:"
    echo "$attr" | sed 's/^/  /'
  done
}


meta_sh_loadenv ()
{
  . "$US_BIN"/meta.lib.sh && meta_lib_load &&
  . "$US_BIN"/metadir.lib.sh && metadir_lib_load &&
  meta_lib_init && metadir_lib_init
}


# Main entry (see user-script.sh for boilerplate)

test -n "${user_script_loaded:-}" || {
  . "${US_BIN:="$HOME/bin"}"/user-script.sh &&
      user_script_shell_env
}

! script_isrunning "meta.sh" || {
  # Pre-parse arguments

  script_defcmd=check
  #user_script_defarg=defarg\ aliasargv

  eval "set -- $(user_script_defarg "$@")"
}

script_entry "meta.sh" "$@"
