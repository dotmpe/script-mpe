#!/bin/sh
set -e


vfs_lib__load ()
{
  export rund=/var/run/htdocs/vfs/

  test -w "$rund" && pref= || {
    warn "vfs.lib: Using sudo to access $rund"
    pref=sudo
  }
  $pref mkdir -p $rund
  test -z "$pref" || $pref chown $(whoami):staff $rund
}


htd_vfs_mount()
{
  test -n "$1" || error "source name expected" 1
  test -n "$2" || error "mount-point expected" 1
  test -n "$3" || set -- "$1" "$2" "HideBrokenSymlinks"
  test -z "$4" || error "surplus arguments '$4'" 1
  python ~/project/x-python-vfs/x-fuse.py \
      $2 "$3('/Volumes/$1')" "$3:$1" $rund/$1.pid1 &&
              note "Mounted $3 VFS at $2" ||
              warn "Failed $3 VFS at $2" 1

  trueish "$verify" && {
      sleep 2
      htd_vfs_running "$1" || error "VFS not running '$1'" 1
  }
  echo "$3" > $rund/$1.class
  note "Mounted $3 at $2"
}

htd_vfs_umount()
{
  test -n "$1" || error "source name expected" 1
  test -n "$2" || error "mount-point expected" 1
  test -z "$3" || error "surplus arguments '$3'" 1
  set -- "$1" "$2" "$(cat $rund/$1.class)"
  umount $2
  trueish "$verify" && {
      sleep 2
      htd_vfs_running "$1" && error "VFS still running '$1'" 1
  }
  rm $rund/$1.class
  note "Unmounted $3 from $2"
}

htd_vfs_mounted()
{
  test -n "$1" || error "source name expected" 1
  test -n "$2" || set -- "$1" "$(cat $rund/$1.class)"
  test -z "$3" || error "surplus arguments '$3'" 1
  mount | grep -q "^$2"'\:'"$1" || return $?
}

htd_vfs_running()
{
  test -n "$1" || error "source name expected" 1
  test -z "$2" || error "surplus arguments '$2'" 1
  test -s $rund/$1.pid1 || error "VFS PID file missing '$1'" 1
  ps aux | eval grep -q "'^$(whoami) *\\<$(cat $rund/$1.pid1)\\>'" || return $?
}

htd_vfs_check()
{
  test -n "$1" || error "source name expected" 1
  set -- "$1" "$(cat $rund/$1.class)"
  htd_vfs_mounted "$1" || error "VFS name not found '$1'" 1
  htd_vfs_running "$1" || error "VFS not running '$1'" 1
  note "$2 VFS running ok"
}
