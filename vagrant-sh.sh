#!/bin/sh
# Created: 2017-02-25
vagrant_sh__source=$_

set -e



version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

vagrant_sh_man_1__list="Global list: cached info about every Vagrant instance"
vagrant_sh__list()
{
  stderr info "Listing vagrant instances ($ vagrant global-status)"
  vagrant_sh__list_raw |
  while read ID NAME PROVIDER STATE DIRECTORY PROVIDER_ID METADIR
  do
    $LOG header1 "$PROVIDER:$ID" "$NAME ($PROVIDER_ID): $STATE" "$DIRECTORY"
  done
}
vagrant_sh__global_status=list


vagrant_sh_spc__list_raw='list-raw [GLOB [FMT]]'
vagrant_sh__list_raw()
{
  check_argc 2
  test -n "$2" && set -- "$1" "$(str_upper "$2")" || set -- "$1" TAB
  vagrant global-status | tail -n +3 |
    while read ID NAME PROVIDER STATE DIRECTORY
    do
      # NOTE: no warning on bugs, ignore non table lines
      test -d "$DIRECTORY" || continue
      export METADIR="$DIRECTORY/.vagrant/machines/$NAME/$PROVIDER/"
      test -e "$METADIR/id" && {
        PROVIDER_ID="$(cat $METADIR/id)"
      } || warn "No ID found for $PROVIDER provider of $NAME"
      # NOTE: output col/cell
      # FIXME: want global counter for row too
      varsfmt "$2" ID NAME PROVIDER STATE DIRECTORY PROVIDER_ID METADIR | grep -v '^#'
    done
}


vagrant_sh_man_1__info="Update local instance and show details"
vagrant_sh__info()
{
  test -z "$1" && {
    vagrant status | tail -n +3
  } || {
    vagrant status | grep "^$1"
  }
}


vagrant_sh_man_1__status="Update local instance and show details"
vagrant_sh__status()
{
  test -n "$1" || set -- default
  local vgrnt_stat_="$(vagrant status | grep "^$1\ .*([a-z\ ]*)$" | sed 's/^'$1'\ *//')"
  vgrnt_stat=
  vgrnt_stat_msg=
  test -n "$vgrnt_stat_" || return 10
  vgrnt_provider="$(echo "$vgrnt_stat_" | sed 's/.*(\(.*\))$/\1/')"
  vgrnt_stat_msg="$(echo "$vgrnt_stat_" | sed 's/\ *(.*)$//')"
  case "$vgrnt_stat_msg" in
    saved ) export vgrnt_stat=3 ;;
    "not created" ) export vgrnt_stat=2 ;;
    running ) export vgrnt_stat=0 ;;
    * ) export vgrnt_stat=9 ;;
  esac
  echo $vgrnt_stat_msg
  return $vgrnt_stat
}


vagrant_sh_man_1__info_raw="Update cache and give parsed details for local VM"
vagrant_sh_spc__info_raw=" GREP [ FMT ] "
vagrant_sh__info_raw()
{
  test -n "$1"
  test -n "$2" && set -- "$1" "$(str_upper "$2")" || set -- "$1" TAB
  local NAME= STATUS= PROVIDER=
  vagrant_sh__info "$1" | while read NAME STATUS qprov
  do
    PROVIDER="$(echo "$qprov"|tr -d '()' )"
    DIRECTORY=$(pwd)
    RDIRECTORY=$(pwd -P)
    # NOTE: pick some local vars per VM
    test -z "$PROVIDER_ID" || {
      VBoxManage showvminfo $PROVIDER_ID --machinereadable
      eval $(VBoxManage showvminfo $PROVIDER_ID --machinereadable)
      lvars="name group ostype"
    }
    # TODO: set counter and only output header once or very X rows
    varsfmt "$2" NAME STATUS PROVIDER DIRECTORY RDIRECTORY \
      $lvars | grep -v '^#'
  done
}


vagrant_sh_man_1__list_info="Update and list actual info about Vagrant instances"
vagrant_sh__list_info()
{
  stderr info "Getting details for running vagrant instances ($ cd DIR && vagrant status)"
  vagrant_sh__list_raw "$1" SH | grep -v '^#' | while read lvars
  do
    (
      eval local $lvars
      test -e "$DIRECTORY" || { warn "missing dir '$DIRECTORY'"
        continue
      }
      cd $DIRECTORY
      vagrant_sh__info_raw "$NAME"
      echo name=$name ostype=$ostype groups=$groups
    )
  done
}
vagrant_sh_als__details=list-info
vagrant_sh_als__update=list-info


vagrant_sh__synced_folders()
{
  vagrant_sh__list_raw |
  while read ID NAME PROVIDER STATE DIRECTORY PROVIDER_ID METADIR
  do
    PROVIDER_SFJSON="$METADIR/synced_folders"
    test -e "$PROVIDER_SFJSON" || {
      $LOG warn "$PROVIDER:$PROVIDER_ID" "No synced-folders data for $NAME ($ID) state: $STATE" "$DIRECTORY"
      continue
    }
    #$LOG header1 "$PROVIDER:$PROVIDER_ID" "$NAME ($ID) state: $STATE" "$DIRECTORY"
    rsync="$(jsotk keys -O lines $PROVIDER_SFJSON rsync)"
    provider="$(jsotk keys -O lines $PROVIDER_SFJSON $PROVIDER)"
    for path in $rsync; do $LOG header1 "$PROVIDER:$PROVIDER_ID" "$NAME ($STATE) rsync: $path"
    done
    for path in $provider; do $LOG header1 "$PROVIDER:$PROVIDER_ID" "$NAME ($STATE) $PROVIDER: $path"
    done
    #note "Folders: $(var2tags rsync $PROVIDER)"
    #$LOG header1 "$PROVIDER:$PROVIDER_ID" "$(var2tags rsync $PROVIDER)" "$DIRECTORY"
  done
}



# Generic subcmd's

vagrant_sh_man_1__help="Usage help. "
vagrant_sh_spc__help="-h|help"
vagrant_sh__help()
{
  test -z "$dry_run" || stderr note " ** DRY-RUN ** " 0
  (
    base=vagrant_sh \
      choice_global=1 std__help "$@"
  )
}
#vagrant_sh_als__h=help
# FIXME:
#vagrant_sh_als__help=help


vagrant_sh_man_1__version="Version info"
vagrant_sh__version()
{
  echo "script-mpe:$scriptname/$version"
}
#vagrant_sh_als___V=version
#vagrant_sh_als____version=version


vagrant_sh__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
vagrant_sh_als___e=edit


# Script main functions

vagrant_sh_main()
{
  local
      scriptname=vagrant-sh \
      base=$(basename $0 .sh) \
      verbosity=5 \
      scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
      failed=

  vagrant_sh_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        vagrant_sh_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# FIXME: Pre-bootstrap init
vagrant_sh_init()
{
  test -n "$LOG" ||
    export LOG=/usr/local/share/mkdoc/Core/log.sh

  test -n "$scriptpath"
  . $scriptpath/util.sh
  lib_load
  . $scriptpath/tools/sh/box.env.sh
  box_run_sh_test
  lib_load main meta box doc date table remote
  # -- vagrant-sh box init sentinel --
}

# FIXME: 2nd boostrap init
vagrant_sh_lib()
{
  local __load_lib=1
  # -- vagrant-sh box lib sentinel --
  set --
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
vagrant_sh_load()
{
  test -n "$VAGRANT_HOME" || error "Expected VAGRANT_HOME env" 1
  test -n "$VAGRANT_NAME" || export VAGRANT_NAME=default
  # -- vagrant-sh box lib sentinel --
  set --
}

# Post-exec: subcmd and script deinit
vagrant_sh_unload()
{
  local unload_ret=0

  #for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  #do case "$x" in
  # ....
  #    f )
  #        clean_failed || unload_ret=1
  #      ;;
  #esac; done

  clean_failed || unload_ret=$?

  unset subcmd subcmd_pref \
          def_subcmd func_exists func \
          failed

  return $unload_ret
}


# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test "$1" != load-ext || __load_lib=1
  test -n "$__load_lib" || {
    vagrant_sh_main "$@" || exit $?
  }
;; esac

# Id: script-mpe/0.0.4-dev vagrant-sh.sh
