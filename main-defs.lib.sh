#!/bin/sh
# Main-Defs: standard definitions for init, lib, load and unload handlers
#   for use with main.lib.
# Created: 2020-06-30


main_main() # Base Local-Vars Default-Cmd Alias
{
  test -n "${main_id-}" || {
    local vid; mkvid $1; main_id=$vid
  }
  test -n "${main_script-}" || main_script="\$0"
  test -n "${main_base-}" || main_base="\$(basename \$0 .sh)"
  test -n "${main_scriptpath-}" ||
      main_scriptpath="\$(cd \"\$(dirname \"\$0\")\"; pwd -P)"
  test -n "${make_pref-}" || local make_pref=eval
  while test $# -lt 3; do set -- "$@" ""; done
  test -n "${4-}" || set -- "$@" "$1"
  $make_pref "$(cat <<EOM

${main_id}_main()
{
  local \
      script="$main_script" \
      scriptname=$1 \
      alias=$4 \
      base="$main_base" \
      scriptpath="$main_scriptpath" $2 \
      subcmd=\${1-$3} subcmd_alias subcmd_func subcmd_default prev_subcmd \
      subcmd_func func_name func_exists \
      box_prefix ${main_local-}

  ${main_id}_main_init || exit \$?

  case "\$base" in

    \$scriptname | \$alias )
        test "\$base" = "\$alias" && base=\$scriptname
EOM
  test -z "$3" || cat <<EOM
        test -n "\${1-}" || set -- $3
EOM
  test -z "${main_lib-}" || cat <<EOM
        ${main_id}_main_lib || exit \$?
EOM
  cat <<EOM
        main_subcmd_run "\$@" || exit \$?
      ;;

    * )
        error "not a frontend for \$base (\$scriptname)" 1
      ;;

  esac
}
EOM
  )"
}

main_define() # 1:Base 2:Init 3:Lib 4:Load 5:Load-Flags 6:Unload 7:Unload-Flags
{
  local main_init="$2" main_lib="$3" main_load="$4" main_load_flags="$5" main_unload="$6" main_unload_flags="$7"
  main_make "$1"
}

main_make()
{
  test -n "${make_pref-}" || make_pref=eval
  test -n "${main_id-}" || {
    local vid; mkvid $1; main_id=$vid
  }

  type_exists ${main_id}_main ||
      main_main "$1" "${make_local-}" "${make_default-"\${subcmd_def-default}"}"

  type_exists ${main_id}_init ||
      $make_pref "$(cat <<EOM

${main_id}_main_init()
{
  local scriptname_old=\$scriptname; export scriptname=$1-main-init

  ${main_init-}
  ${main_env-} . \${CWD:="\$scriptpath"}/tools/main/init.sh || return
  # -- $1 box init sentinel --
  export scriptname=\$scriptname_old
}
EOM
      )"

  { type_exists ${main_id}_main_lib || test -z "${main_lib-}"
  } ||
      $make_pref "$(cat <<EOM

${main_id}_main_lib()
{
  local scriptname_old=\$scriptname; export scriptname=$1-main-lib

  $main_lib
  # -- $1 box lib sentinel --
  export scriptname=\$scriptname_old
}
EOM
      )"

  { type_exists ${main_id}_subcmd_load ||
      test -z "${main_load-}" -a -z "${main_load_flags-}"
  } || {
      test -n "${main_load_flags_def-}" ||
          local main_load_flags_def="* ) error \"No load flag '\$x'\" 3 ;;"
      $make_pref "$(cat <<EOM

# Pre-exec: post subcmd-boostrap init
${main_id}_subcmd_load()
{
  local scriptname_old=\$scriptname; export scriptname=$1-subcmd-load

  ${main_load-}
  # -- $1 box load sentinel --

  local flags="\$(try_value "\${subcmd}" flags | sed 's/./&\ /g')"
  for x in \$flags
  do case "\$x" in
    ${main_load_flags-$main_load_flags_def}
  esac; done
  export scriptname=\$scriptname_old
}
EOM
      )"
  }

  { type_exists ${main_id}_subcmd_unload ||
      test -z "${main_unload-}" -a -z "${main_unload_flags-}"
  } || {
      test -n "${main_unload_flags_def-}" ||
          local main_unload_flags_def="* ) error \"No unload flag '\$x'\" 3 ;;"
      $make_pref "$(cat <<EOM

# Post-exec: subcmd and script deinit
${main_id}_subcmd_unload()
{
  local scriptname_old=\$scriptname; export scriptname=$1-subcmd-unload
  local unload_ret=0

  ${main_unload-}
  # -- $1 box unload sentinel --

  for x in \$(try_value "\${subcmd}" "" flags| sed 's/./&\ /g')
  do case "\$x" in
    ${main_unload_flags-"$main_unload_flags_def"}
  esac; done
  export scriptname=\$scriptname_old
  return \$unload_ret
}
EOM
      )"
  }
}

main_entry()
{
  test -n "${make_pref-}" || local make_pref=eval

  $make_pref "$(cat <<EOM
# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "\$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  case "\${1-}" in
    load-ext ) ;;
    * )
      ${main_id}_main "\$@" ;;

  esac ;;
esac

${main_epilogue-}
EOM
  )"
}

# Id: script-mpe/0.0.4-dev main-defs.lib.sh
