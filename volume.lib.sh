#!/bin/sh

source_device_catalog() # Device [Hostname]
{
  disk_id="$(disk_id_for_dev "$1")" || return
  . $DISK_CATALOG/disk/$disk_id.sh
  test -z "$2" -o "$disk_host" = "$2" || return
  . $DISK_CATALOG/host/$disk_host.sh
  test -n "$disk_host_default_mount" || disk_host_default_mount=/tmp
}

# TODO: base alt. version on scanning mount
htd_list_volumes()
{
  trueish "$catalog" && {
    note "Listing volumes from catalog for $hostname"
    disk_list | while read dev
    do
      source_device_catalog "$dev" "$hostname" || continue
      test -n "$disk_volumes" || exit 123
      idx=0
      for volume in $disk_volumes
      do
        idx=$(( idx + 1 ))
        test -e $disk_host_default_mount/$volume || { error "No $volume"; continue; }
        echo $disk_host_default_mount/$volume
      done
    done
    return $?
  }
  trueish "$catalog" || {
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
    disk_list | while read dev
    do
      prefix=$(disk.sh prefix $dev 2>/dev/null)
      test -n "$prefix" || {
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
        eval $(sed 's/^volumes_main_/vol_/' $volume/.volumes.sh)

        test "$vol_prefix" = "$prefix" \
          || error "Prefix mismatch '$vol_prefix' != '$prefix' ($volume)" 1

        # Check for unknown service roots
        test -n "$vol_export_all" || vol_export_all=1
        trueish "$vol_export_all" && {
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
        test -n "$vol_aliases__1" \
          || error "Expected one aliases ($volume)"

        test -e "/srv/$vol_aliases__1"  || {
          error "Missing volume alias '$vol_aliases__1' ($volume)" 1
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

        note "Volumes OK: $disk_index.$vol_part_index $volume"

        unset srv \
          vol_prefix \
          vol_aliases__1 \
          vol_export_all

      done
      note "Disk OK: $disk_index. $prefix"
    done
    return $?
  }

  trueish "$catalog" && {
    note "Listing volumes for current mounts"
    disk_mounts | while read mount_point
    do
      source_mount_catalog $mount_point
      _volume_symlink
      test -e /srv/$sym && {
        info "Found volume-$disk_index-$vol_part_index-$suffix"
        continue
      }
      echo ln -s $mount_point /srv/$sym
      note "New volume-$disk_index-$vol_part_index-$suffix"
    done
    return $?
  }
}

source_mount_catalog()
{
  test -e $mount_point/.volumes.sh || {
    warn "No volume dotfile on $mount_point" ; continue
  }
  # TODO: should sync marker file with catalog
  # Get data from online marker file
  eval $(sed 's/^volumes_main/vol/g' $mount_point/.volumes.sh)
  # Get data from catalog
  . $DISK_CATALOG/disk/$vol_disk_id.sh
}

_volume_symlink()
{
  test -n "$disk_domain" &&
      suffix="$(echo "$disk_host-$disk_domain" | tr 'A-Z' 'a-z')" ||
      suffix="$(echo "$disk_host" | tr 'A-Z' 'a-z')"
  sym=volume-$disk_index-$vol_part_index-$suffix
}

# Give pathname.tab for use with htd prefixes
htd_path_names()
{
  info "Listing path names for current mounts"
  # Reverse list b/c/ pathnames.tab root should come last
  disk_mounts | sort -r | while read mount_point
  do
    source_mount_catalog $mount_point
    _volume_symlink
    # anyway...
    rd="$(cd "$mount_point" && pwd -P)"
    echo /srv/$sym/ $vol_prefix
    test "$mount_point" = "$rd" || echo $rd/ $vol_prefix
    fnmatch "*/" $mount_point || mount_point=$mount_point/
    echo $mount_point $vol_prefix
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
