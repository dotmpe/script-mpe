#!/bin/sh


volumestat_lib_load()
{
  vstdir=$HOME/htdocs/.build/stat/volume/
  mkdir -p $vstdir

  case "$uname" in

    Darwin )
        voldir=/Volumes
      ;;

    Linux )
        voldir=/mnt
      ;;

    * ) error "volumestat-lib-load uname=$uname" 1 ;;

  esac
}

htd_volumestat_check()
{
  test -n "$1" || error "volume name expected" 1
  test -n "$2" || set -- "$1" "$vstdir/$1"
  {
    test -e "$voldir/$1/.cllct/hooks/check" && {
      "$voldir/$1/.cllct/hooks/check" || return $?
    } || true
  } || { r=$?
    echo $r > "$2.error"
    error "Error check '$1' ($r)"
    return 1
  }
}

htd_volumestat_oninit()
{
  test -n "$1" || error "volume name expected" 1
  test -n "$2" || set -- "$1" "$vstdir/$1"
  {
    test -e "$voldir/$1/.cllct/hooks/on-init" && {
      "$voldir/$1/.cllct/hooks/on-init" || return $?
    } || true
  } && {
    touch "$2.mounted"
  } || { r=$?
    echo $r > "$2.error"
    error "Error on-init '$1' ($r)"
    return 1
  }
}

htd_volumestat_ondeinit()
{
  test -n "$1" || error "volume name expected" 1
  test -n "$2" || set -- "$1" "$vstdir/$1"
  {
    test -e "$voldir/$1/.cllct/hooks/on-deinit" && {
      "$voldir/$1/.cllct/hooks/on-deinit" || return $?
    } || true
  } && {
    rm "$2.mounted"
  } || { r=$?
    echo $r > "$2.error"
    error "Error updating '$1' ($r)"
    return 1
  }
}

# On appearance/dissappearance of volumestat, mark it for init or deinit
htd_volumestat_update()
{
  htd_volumestat_stat || warn "volstat stat ($?)"
  htd_volumestat_init || warn "volstat init ($?)"
  htd_volumestat_deinit || warn "volstat deinit ($?)"
}

htd_volumestat_init()
{
  test -z "$*" || error "unexpected arguments '$*'" 1
  for stat_init in "$vstdir"/*.init
  do
    test -e "$stat_init" || continue
    name="$(basename "$stat_init" .init)"
    stat="$vstdir/$name"
    vol="$voldir/$name"
    htd_volumestat_oninit "$name" "$stat" && {
      rm "$stat.init"
    } || continue
  done
}

htd_volumestat_deinit()
{
  test -z "$*" || error "unexpected arguments '$*'" 1
  for stat_deinit in "$vstdir"/*.deinit
  do
    test -e "$stat_deinit" || continue
    name="$(basename "$stat_deinit" .deinit)"
    stat="$vstdir/$name"
    vol="$voldir/$name"
    htd_volumestat_ondeinit "$name" "$stat" && {
      rm "$stat.deinit"
    } || continue
  done
}

htd_volumestat_umount()
{
  test -n "$1" || error "volume name expected" 1
  test -z "$2" || error "surpluss arguments '$2'" 1
  stat="$vstdir/$1"
  test -e "$stat.mounted" || error "No mount '$1'" 1
  touch $stat.deinit $stat.umount
  htd_volumestat_deinit
  rm "$stat.umount"
  test "$uname" = "Darwin" && {
    sudo diskutil unmount /Volumes/$1/
  } || {
    sudo umount /Volumes/$1/
  }
}

htd_volumestat_stat()
{
  test -z "$*" || error "unexpected arguments '$*'" 1
  for vol in "$voldir"/*
  do
    test -e "$vol" || continue
    name="$(basename "$vol")"
    stat="$vstdir/$name"
    test -e "$stat.mounted" -o -e "$stat.umount" || {
      touch "$stat.init"
      note "'$name' was mounted"
    }
  done
  for stat_mounted in "$vstdir"/*.mounted
  do
    test -e "$stat_mounted" || continue
    name="$(basename "$stat_mounted" .mounted)"
    stat="$vstdir/$name"
    vol="$voldir/$name"
    test -e "$vol" || {
      note "'$name' was unmounted"
      touch "$stat.deinit"
    }
  done
}
