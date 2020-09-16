#!/usr/bin/env make.sh
# Created: 2016-02-22

set -eu -o posix



version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

diskdoc_flags__meta=y
diskdoc_man_1__meta='Defer to python script for YAML parsing'
diskdoc__meta()
{
  test -n "$1" || set -- --background

  fnmatch "$1" "-*" || {

    # Use socat as client, else performance is almost as bad as re-invoking
    # Python program each call.
    test -x $(which socat) -a -e "$sock" && {
      printf -- "$*\r\n" | socat -d - "UNIX-CONNECT:$sock" \
        2>&1 | tr "\r" " " | while read line
      do
        case "$line" in
          *" OK " )
            return
            ;;
          "? "* )
            return 1
            ;;
          "! "*": "* )
            return $(echo $line | sed 's/.*://g')
            ;;
        esac
        echo $line
      done
      return
    }
  }

  diskdoc.py -f $diskdoc --address $sock "$@" || return $?
}

# silent/quit
diskdoc__meta_sq()
{
  diskdoc__meta "$@" >/dev/null || return $?
}


diskdoc_flags__status=ybf
diskdoc_man_1__help='Run over known prefixes and present status indicators'
diskdoc__status()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  note "Getting status for checkouts $prefix"
  diskdoc.py disks | while read mount device type
  do
    note "TODO: check disk $mount"
    #vc_check $prefix || continue
    #test -d "$prefix" || continue
    #diskdoc__clean $prefix || touch $failed
  done
  rm_failed
}


diskdoc_flags__check=ybf
diskdoc_man_1__check='Check with remote refs'
diskdoc__check()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  note "Checking prefixes"
  diskdoc__meta list-disks "$1" | while read -r prefix
  do
    vc_check $prefix || continue
    test -d "$prefix" || continue
    diskdoc sync $prefix || touch $failed
  done
  rm_failed
}


#diskdoc_flags__update=yfb
diskdoc__update()
{
  test -n "$1" || set -- "*"

  backup_if_comments "$diskdoc"
}



diskdoc_flags__init=y
diskdoc__init()
{
  false
}


diskdoc_flags__ids=y
diskdoc__ids()
{
  sudo blkid | while read -r devicer uuidr typer partuuidr
  do
    device=$(echo $devicer | cut -c-$(( ${#devicer} - 1 )))
    uuid=$(echo $uuidr | cut -c7-$(( ${#uuidr} - 8 )))
    type_=$(echo $typer | cut -c7-$(( ${#typer} - 1 )))
    partuuid=$(echo $partuuidr | cut -c11-$(( ${#partuuidr} - 1 )))

    grep -Fq $uuid $HOME/.conf/disk/mpe.yaml || {
      note "Unknown disk: $device $uuid "
    }
    grep -Fq $partuuid $HOME/.conf/disk/mpe.yaml || {
      note "Unknown partition: $device $type_ $partuuid "
    }
  done
}


# Generic subcmd's


diskdoc__edit()
{
  $EDITOR $0 $(which diskdoc.py) "$@"
}



# Script main functions

main_init_env INIT_ENV="init-log strict 0 0-src 0-u_s dev ucache scriptpath std box" \\
  INIT_LIB="\$default_lib logger-theme main box src meta std stdio vc date match str-htd ctx-main ctx-std"

main_local \\
  scsep=__ bgd= \\
  diskdoc_default def_subcmd func_exists func \\
  failed diskdoc_session_id \\
  diskdoc_session_id= \\
  subcmd_default=status \\
  func_exists= \\
  func= \\
  main_bg=diskdoc__meta \\
  main_sock= \\
  c=0

main_load \
  local tdy="$(try_value "${subcmd}" "" today)" \
  test -z "$tdy" || { \
    today=$(statusdir.sh file $tdy) \
    tdate=$(date +%y%m%d0000) \
    test -n "$tdate" || error "formatting date" 1 \
    touch -t $tdate $today \
  }

main_load_flags \
      y ) \
        # set/check for Pd for subcmd \
        diskdoc=projects.yaml \
 \
        # Find dir with metafile \
        prerun=$PWD \
        prefix=$2 \
 \
        while test ! -e "$diskdoc" \
        do \
          test -n "$prefix" \\
            && prefix="$(basename $PWD)/$prefix" \\
            || prefix="$(basename $PWD)" \
          cd .. \
          test "$PWD" = "/" && break \
        done \
 \
        test -e "$diskdoc" || error "No projects file $diskdoc" 1 \
        p="$(realpath $diskdoc | sed 's/[^A-Za-z0-9_-]/-/g' | tr -s '_' '-')" \
        main_sock=/tmp/diskdoc-$p-serv.sock \
        ;; \
 \
      f ) \
        # Preset name to subcmd failed file placeholder \
        #req_vars base subcmd \
        # Preset name to subcmd failed file placeholder \
        # include realpath of projectdoc (p) \
        test -n "${pd-}" && { \
          export failed=$(setup_tmpf .failed -$p-$subcmd-$diskdoc_session_id) \
        } || failed=$(setup_tmpf .failed -$subcmd-$diskdoc_session_id ) \
        ;; \
 \
      b ) \
          # run metadata server in background for subcmd \
          box_bg_setup \
        ;;

main_unload_flags \
      y ) \
          test -z "$main_sock" || { \
            box_bg_teardown \
            unset bgd main_sock \
          } \
        ;; \
      f ) \
          clean_failed || unload_ret=1 \
        ;;

main_load_epilogue \
# Id: script-mpe/0.0.4-dev diskdoc.sh
