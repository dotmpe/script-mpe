#!/bin/sh


volume_lib_load()
{
  sd=$HOME/htdocs/.build/stat
  mkdir -p $sd

  case "$uname" in

    Darwin )
        voldir=/Volumes
      ;;

    * ) error "volume-lib-load uname=$uname" 1 ;;

  esac
}

volume()
{
  test -n "$1" || set -- init
  case "$1" in

    # Run up/down hooks
    mount )
        {
          test -e "$voldir/$2/.cllct/hooks/on-$1" && {
            "$voldir/$2/.cllct/hooks/on-$1" || return $?
          } || true
        } && {
          touch "$3.mounted"
        } || { r=$?
          echo $r > "$3.error"
          error "Error updating ($r)"
          return 1
        }
      ;;

    unmount )
        {
          test -e "$voldir/$2/.cllct/hooks/on-$1" && {
            "$voldir/$2/.cllct/hooks/on-$1" || return $?
          } || true
        } && {
          rm "$3.mounted"
        } || { r=$?
          echo $r > "$3.error"
          error "Error updating ($r)"
          return 1
        }
      ;;

    # On appearance/dissappearance of volume, mark it for init or deinit
    update ) shift
        volume stat || warn "stat ($?)"
        volume init || warn "init ($?)"
        volume deinit || warn "deinit ($?)"
      ;;

    init ) shift
        for stat_init in "$sd"/*.init
        do
          test -e "$stat_init" || continue
          name="$(basename "$stat_init" .init)"
          stat="$sd/$name"
          vol="$voldir/$name"
          volume mount "$name" "$stat" && {
            rm "$stat.init"
          } || continue
        done
      ;;

    deinit ) shift
        for stat_deinit in "$sd"/*.deinit
        do
          test -e "$stat_deinit" || continue
          name="$(basename "$stat_deinit" .deinit)"
          stat="$sd/$name"
          vol="$voldir/$name"
          volume unmount "$name" "$stat" && {
            rm "$stat.deinit"
          } || continue
        done
      ;;

    stat ) shift
        for vol in "$voldir"/*
        do
          test -e "$vol" || continue
          name="$(basename "$vol")"
          stat="$sd/$name"
          test -e "$stat.mounted" || {
            touch "$stat.init"
            note "'$name' was mounted"
          }
        done
        for stat_mounted in "$sd"/*.mounted
        do
          test -e "$stat_mounted" || continue
          name="$(basename "$stat_mounted" .mounted)"
          stat="$sd/$name"
          vol="$voldir/$name"
          test -e "$vol" || {
            note "'$name' was unmounted"
            touch "$stat.deinit"
          }
        done
      ;;

  esac
}

volume_utils_no_symlinks()
{
  echo
}
