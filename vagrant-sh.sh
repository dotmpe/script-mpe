#!/usr/bin/env make.sh
# Created: 2017-02-25

version=0.0.4-dev # script-mpe

set -eu


# Script subcmd's funcs and vars

# See $scriptname help to get started

vagrant_sh_man_1__list="Global list: cached info about every Vagrant instance"
vagrant_sh__list()
{
  stderr info "Listing vagrant instances ($ vagrant global-status)"
  $LOG header2 "Provider:Id" "Name (Provider-Id): State" "Directory"
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


vagrant_sh__update_all()
{
  vagrant global-status | tail -n +3 |
    while read ID NAME PROVIDER STATE DIRECTORY
    do
      test "$PROVIDER" = "virtualbox" || continue
      test -d "$DIRECTORY" || {
          warn "No present dir '$DIRECTORY'"
          continue
      }
      cd $DIRECTORY && vagrant update
    done
}


vagrant_sh__list_dirs()
{
  vagrant global-status |
    tail -n +3 |
    while read ID NAME PROVIDER STATE DIRECTORY
    do
      test "$PROVIDER" = "virtualbox" || continue
      test -d "$DIRECTORY" || {
        warn "No present dir '$DIRECTORY'"
        continue
      }
      cd $DIRECTORY
      pwd -P
    done
}

vagrant_sh__status_all()
{
  vagrant global-status |
    tail -n +3 |
    while read ID NAME PROVIDER STATE DIRECTORY
    do
      test "$PROVIDER" = "virtualbox" || continue
      test -d "$DIRECTORY" || {
        warn "No present dir '$DIRECTORY'"
        continue
      }
      note "ID: $ID  Name: $NAME"
      cd $DIRECTORY && {
        pwd -P
        vagrant status
        vagrant_sh__status "$NAME" || echo status=$?
      }
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
  test -n "$vgrnt_stat_" || { warn "No local staltus" ; return 10 ; }
  vgrnt_stat=
  vgrnt_stat_msg=
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
    DIRECTORY=$PWD
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


vagrant_sh_als____help=help
vagrant_sh_als___h=help
vagrant_sh_grp__help=ctx-main\ ctx-std


vagrant_sh_als____version=version
vagrant_sh_als___V=version
vagrant_sh_grp__version=ctx-main\ ctx-std


vagrant_sh__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
vagrant_sh_als___e=edit


# Script main functions


#INIT_ENV="init-log 0 0-src 0-u_s 0-std 0-1-lib-sys ucache scriptpath box" \
#INIT_LIB="\$default_lib main meta box doc date table remote std stdio"
#  main_define \
#    vagrant-sh \
#    'failed=' '
#  # Vagrant-Sh init
#' '
#  # Vagrant-Sh lib
#' '
#  # Vagrant-Sh load
#  local upper=1
#  default_env Vagrant-Home "$HOME/.vagrant"
#  default_env Vagrant-Home "default"
#' '
#  # Vagrant-Sh load-flags
#' '
#  # Vagrant-Sh unload
#  #    f )
#  #        clean_failed || unload_ret=1
#  clean_failed || unload_ret=$?
#  unset subcmd_pref \
#          def_subcmd func_exists func \
#          failed
#' '
#  # Vagrant-Sh unload-flags
#'

# Id: script-mpe/0.0.4-dev vagrant-sh.sh
