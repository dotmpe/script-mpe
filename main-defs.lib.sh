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
      scriptpath="$main_scriptpath" $2 \
      subcmd=\${1-$3} subcmd_alias subcmd_default prev_subcmd \
      alias=\$(echo $4 | cut -d' ' -f1) \
      subcmd_func func_name func_exists \
      base="$main_base" \
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

main_define() # 1:Base 2:Local-Vars 3:Init 4:Lib 5:Load 6:Load-Flags 7:Unload 8:Unload-Flags
{
  local main_local="$2" main_init="$3" main_lib="$4" main_load="$5" main_load_flags="$6" main_unload="$7" main_unload_flags="$8"
  main_make "$1"
}

main_make()
{
  test -n "${make_pref-}" || make_pref=eval
  test -n "${main_id-}" || {
    local vid; mkvid $1; main_id=$vid
  }

  # Declare an entry point for base unless make-bases is given
  { type_exists ${main_id}_main || test -n "${main_bases-}"
  } || {
    main_main "$1" "${main_local-}" \
        "${make_default-"\${subcmd_default-default}"}" \
        "${make_aliases-"\${aliases-$make_scriptname}"}"
  }

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
  # Choose main-entry form: 1 or multiple bases
  local main_call
  echo make_script: $make_script
  echo make_scriptname: $make_scriptname
  echo 0:$0
  test -n "${main_bases-}" && {
    main_call="
  echo 0:\$0
  echo main_bases:\$main_bases
exit 123
. \$HOME/bin/main.lib.sh && main_lib_load && main_lib_loaded=\$?
${main_local-} main_run_static \"$main_bases\" \"\$@\""
  } || {
    main_call="${main_id}_main \"\$@\""
  }
  $make_pref "$(cat <<EOM
# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "\$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test "load-ext" != "\${1-}" || __load=ext
  case "\${__load-}" in
    ext ) ;;
    * ) ${main_call} ;;

  esac ;;
esac

${main_epilogue-}
EOM
  )"
}

# Id: script-mpe/0.0.4-dev main-defs.lib.sh
