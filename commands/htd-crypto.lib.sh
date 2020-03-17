#!/bin/sh

htd_man_1__crypto='
  list         Show local volumes with crypto folder
  find         Find local crypto volume with specific volume Id.
  find-all     Show all volume Ids found on local volume paths.
  check        See if htd crypto is good to go
'
htd__crypto()
{
  test -n "$1" || set -- check
  # TODO: use crypto source or something
  cr_m=$HTDIR/crypto/main.tab
  test -e $cr_m || cr_m=~/.local/etc/crypto-bootstrap.tab
  case "$1" in

    list ) htd__crypto_volumes || return ;;
    find ) htd__crypto_volume_find "$@" || return ;;
    list-ids|find-all ) echo "#Volume-Id,File-Size"; htd__crypto_volumes | while read v
      do for p in $v/*.vc ; do echo "$(basename $p .vc) $(filesize "$p")" ; done
      done ;;

    check )
      test -x "$(which veracrypt)" || error "VeraCrypt exec missing" 1
      test -e $cr_m || error cr-m-tab 1
      veracrypt --version || return ;;

    mount-all ) htd__crypto_mount_all || return ;;
    mount ) htd__crypto_mount "$@" || return ;;
    unmount ) htd__crypto_unmount "$@" || return ;;

    * ) error "'$1'? 'htd crypto $*'" 1 ;;
  esac
}

htd__crypto_mount_all()
{
  test -e $cr_m || error cr-m-tab 1
  c_tab() { fixed_table $cr_m Lvl VolumeId Prefix Contexts ; }
  c_tab | while read vars
  do eval $vars
    test -n "$Prefix" || continue
    test -e "$Prefix" || {
      test -d "$(dirname "$Prefix")" || {
        warn "Missing path '$Prefix'"; continue;
      }
      mkdir -p "$Prefix"
    }
    test -d "$Prefix" || { warn "Non-dir '$Prefix'"; continue; }
    Prefix_Real=$(cd "$(dirname "$Prefix")"; pwd -P)/$(basename "$Prefix")
    mountpoint -q "$Prefix_Real" && {
      note "Already mounted: $Lvl: $VolumeId ($Contexts at $Prefix)"
    } || {
      htd__crypto_mount "$Lvl" "$VolumeId" "$Prefix_Real" "$Contexts" && {
        stderr ok "$Lvl: $VolumeId ($Contexts at $Prefix)"
      } || {
        warn "Mount failed"
        continue
      }
    }
    mountpoint -q "$Prefix_Real" || {
      warn "Non-mount '$Prefix'"; continue;
    }
  done
}
htd_run__crypto=f

htd__crypto_mount() # Lvl VolumeId Prefix_Real Contexts
{
  local device=$(htd__crypto_volume_find "$2.vc")
  test -n "$device" || {
    error "No volume found for '$2'"
    return 1
  }
  . ~/.local/etc/crypto.sh
  test -n "$(eval echo \$$2)" || {
    error "No key for $1"
    return 1
  }
  eval echo "\$$2" | \
    sudo veracrypt --non-interactive --stdin -v $device $3
}


htd__crypto_unmount() # VolumeId
{
  local device=$(htd__crypto_volume_find "$1.vc")
  test -n "$device" || error "Cannot find mount of '$1'" 1
  note "Unmounting volume '$1' ($device)"
  sudo veracrypt -d $device
}


htd__crypto_vc_init() # VolumeId Secret Size
{
  test -n "$1" || set -- Untitled0002 "$2"
  test -n "$2" || error passwd-var-expected 1
  test -n "$3" || set -- "$1" "$2" "10M"
  eval echo "\$$2" | \
    sudo veracrypt --non-interactive --stdin \
      --create $1.vc --hash sha512 --encryption aes \
      --filesystem exFat --size $3 --volume-type=normal
  mkdir /tmp/$(basename $1)
  sudo chown $(whoami):$(whoami) $1.vc
  eval echo "\$$2" | \
    sudo veracrypt --non-interactive --stdin \
      -v $1.vc /tmp/$(basename "$1")
}

