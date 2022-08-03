#!/bin/sh

### Manage numbered disks


volume_htd_lib_load ()
{
  true
}

volume_htd_lib_init ()
{
  true
}


# Load config settings for device and host
source_device_catalog() # Device [Hostname]
{
  disk_id="$(disk_id_for_dev "$1")" || { error "No disk-id-for-dev '$1'" ; return 1; }
  test -e $DISK_CATALOG/disk/$disk_id.sh || { error "No catalog for $disk_id" ; return 1; }
  . $DISK_CATALOG/disk/$disk_id.sh
  test -z "$2" -o "$disk_host" = "$2" || return
  . $DISK_CATALOG/host/$disk_host.sh
  test -n "$disk_host_default_mount" || disk_host_default_mount=/tmp
}

# List volume paths
# given device paths
# XXX: choose between scanning static mount dir, mounts output, or everything
# in catalog.
htd_list_volumes()
{
  scan_all=0 scan_dir=1 scan_mounts=1

  trueish "$scan_all" && {
      error "TODO: list-volumes scan-all"
    }

  trueish "$scan_dir" && {

    note "Listing volumes from catalog for $hostname"
    disk_list | while read dev
    do
      source_device_catalog "$dev" "$hostname" || continue
      test -n "$disk_volumes" || exit 123

      idx=0
      for volume in $disk_volumes
      do
        idx=$(( idx + 1 ))
        test -e $disk_host_default_mount/$volume || {

            error "No volume '$volume' ($hostname:$dev:$idx)";
            continue
        }
        echo $disk_host_default_mount/$volume
      done
    done
    return $?
  }

  trueish "$scan_mounts" && {
    note "Listing volumes for current mounts"
    disk_mounts | while read mount_point
    do
      test -e $mount_point/.volumes.sh || {
        warn "No volume dotfile on $mount_point" ; continue
      }
      echo $mount_point
    done
    return $?
  }
}

# Go over local disk to see if volume links are there
htd_check_volumes()
{
  trueish "$catalog" && {
    local r=

    disk_list | { local r=; while read dev
    do
      prefix=$(disk.sh prefix $dev 2>/dev/null)
      test -n "$prefix" || { r=1
        warn "No prefix found for <$dev>"
        continue
      }

      disk_id="$(disk_id_for_dev "$dev")" || continue
      . $DISK_CATALOG/disk/$disk_id.sh
      test "$host" = "$hostname" || continue
      test -n "$volumes" || {
        error "Missing volumes property for $disk_id" ; continue
      }
      idx=0

      for volume in $volumes
      do
        idx=$(( idx + 1 ))
        echo $idx $volume
      done

      disk_index=$(disk.sh info $disk_id disk_index 2>/dev/null)

      for volume in /mnt/$prefix-*
      do
        test -e $volume/.volumes.sh || continue
        eval $(sed 's/^volumes_main_//' $volume/.volumes.sh)

        test "$prefix" = "$prefix" \
          || error "Prefix mismatch '$prefix' != '$prefix' ($volume)" 1

        # Check for unknown service roots
        test -n "$export_all" || export_all=1
        trueish "$export_all" && {
          echo $volume/* | tr ' ' '\n' | while read vroot
          do
            test -n "$vroot" || continue
            vdir=$(basename "$vroot")
            echo $SRVS lost+found | grep -q $vdir || {
              warn "Unkown volume dir $vdir" 1
            }
          done
        }

        # TODO: check all aliases, and all mapping aliases
        test -n "$aliases__1" \
          || error "Expected one aliases ($volume)"

        test -e "/srv/$aliases__1"  || {
          error "Missing volume alias '$aliases__1' ($volume)" 1
        }

        # Go over known services
        for srv in $SRVS
        do
          test -e $volume/$srv && {

            t=/srv/$srv-local
            test -e "$t" || warn "Missing $t ($volume/$srv)"

            # TODO: check for global id as well
            #t=/srv/$srv-${disk_idx}-${part_idx}-$(hostname -s)-$domain
            #test -e "$t" || warn "Missing $t ($volume/$srv)"

          }
        done

        note "Volumes OK: $disk_index.$part_index $volume"

        unset srv \
          prefix \
          aliases__1 \
          export_all

      done
      note "Disk OK: $disk_index. $prefix"
    done; return $r; } || r=$?

    note "Listing volumes for current mounts"
    disk_mounts | { local r=; while read mount_point
    do
      test -r "$mount_point" || { r=1
        warn "No read permission <$mount_point>"
        continue
      }
      source_mount_catalog $mount_point || { r=$?
        error "Sourcing catalog for <$mount_point>"
        continue
      }
      _volume_symlink || { r=$?
        error "Building volume symlink for <$mount_point>"
        continue
      }
      test -e /srv/$sym && {
        std_info "Found volume-$disk_index-$part_index-$suffix"
        continue
      }
      echo ln -s $mount_point /srv/$sym
      note "New volume-$disk_index-$part_index-$suffix"
    done; return $r; } || r=$?

    return $?
  }
}

source_mount_catalog()
{
  local r=
  test -e $mount_point/.volumes.sh || {
    warn "No volume dotfile on $mount_point" ; return
  }

  # TODO: should sync marker file with catalog
  # Get data from online marker file
  eval "$(grep '^volumes_main_' $mount_point/.volumes.sh |
      sed 's/^volumes_main_//g' )"

  # Get data from catalog
  . $DISK_CATALOG/disk/$disk_id.sh
}

_volume_symlink()
{
  test -n "${disk_domain-}" && {
    suffix="$(echo "$disk_host-$disk_domain" | tr 'A-Z' 'a-z')" || return
  } || {
    suffix="$(echo "$disk_host" | tr 'A-Z' 'a-z')" || return
  }
  sym=volume-$disk_index-$part_index-$suffix
}

# Give pathname.tab for use with htd prefixes
htd_path_names()
{
  std_info "Listing path names for current mounts"
  # Reverse list b/c/ pathnames.tab root should come last
  disk_mounts | sort -r | while read mount_point
  do
    source_mount_catalog $mount_point
    _volume_symlink
    # anyway...
    rd="$(cd "$mount_point" && pwd -P)"
    echo /srv/$sym/ $prefix
    test "$mount_point" = "$rd" || echo $rd/ $prefix
    fnmatch "*/" $mount_point || mount_point=$mount_point/
    echo $mount_point $prefix
  done
  return $?
}

htd_volumes_treemap()
{
  # FIXME: htd_list_volumes | while read volume
  for volume in /srv/volume-[0-9]*
  do
    test -e "$volume" || continue
    rd="$(cd $volume && pwd -P)"
    test -d "$rd" || continue
    out="$rd/tmp/df-hs.out"
    {
      test -e "$out" && newer_than "$out" "$_1DAY"
    } || {
      test -d "$rd/tmp" || mkdir -p "$rd/tmp"
      df="$(du -hs "$rd" 2>/dev/null)"
      echo "$df" | tee $out
    }
  done
}

gotovolroot() # [Enable-Source]
{
  cd "$(pwd -P)"
  while true
  do
    test -e ./.volumes.sh || {
      test "$PWD" != "/" || return 1
      cd ..
      continue
    }
    test -z "$1" || . ./.volumes.sh
    break
  done
}

# Find volume disk-id and part-idx by looking for .volumes.sh at root
get_cwd_volume_id() # [DIR] [SEP]
{
  local cwd=$PWD r=
  test -n "$2" || set -- "$1" "-"
  test -n "$1" || cd "$1"
  gotovolroot 1 &&
      printf "$volumes_main_disk_index$2$volumes_main_part_index" || r=$?
  test -n "$1" || cd "$cwd"
  return $r
}
