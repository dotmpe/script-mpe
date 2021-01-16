Disk device query routines
==========================
Disk identifies hard-drive storage attached to the local system, and tracks disks, partitions and volumes.

disk cmd is free so use that. See also ``diskdoc.*``.
Also have some disk handling in htd, consolidated parted parts.

Background
----------
Seems natural to parse ``mount`` output, but want to list all block storage devices. Then could do::

  for dev in /dev/*
  do
    test -b "$dev" || continue   # Skip non-block devices
    mount -x "$dev"              # Print device major:minor number
  done

And compare the block device number with lines from ``/proc/devices``.
However sorting the disks from the partitions requires parsing the
minor numbers. On my Linux machine the interval seems to be 16::

  8:0    # First disk
  8:1    # First disk first partition
  8:16   # Second disk
  8:17   # Second disk first partition, etc.

Rather since we know usual disk drivers for certain systems, we can just parse
the device names, which we get from expanding a glob. This way partition numbers are parsed more easily as well. E.g.::

  /dev/sd[a-z][0-9]
  /dev/sr[a-z][0-9]
  /dev/disk[0-9]p[0-9]
  /dev/mmcblk[0-9]p[0-9]

To identify the disk, several property values can be read from the device using ``fdisk``, ``parted`` or ``blkid``. These usually require sudo, so to verify disk identity in batch scripts some other way is needed.

But more importantly the value to use for identification can be invalid or in case of an bridge or adapter card unreachable. For SD-cards serial numbers can only be retrieved through a MMC block device, not when using an USB adapter. Besides, some OEM SD cards may have duplicate serial numbers. Other values like ``fdisk``'s disk-Id are really checksums of the partition table. So these can be used to identify certain images, but these will change after resizing procedures. For the same reason adding a metadata file to a filesystem is sometimes not desirable.

``/dev/disk/*`` if present will hold useful properties as well. But concatenated together and hard to separate, and caveats mentioned above apply.


Design
------
Finally to identify disks attached to the local system, we could do as ``mount UUID=...`` and query the diskdoc directory for the matching disk.

But that tracks a *partition* and we can't use much of the values we see in `/dev/disk` to reliably track *disks*, so a baser system is needed. And that is a unique mount-point basename assigned to each physical disk. And I just number disks and track them in a table, formatting the prefix something like::

  <Vendor><Series/Iface>-<Disk-Index>-<GB-Size>

Using a known mountpoint basename or a ``.volumes.sh`` root-file allows for quick Id of mounted disks. For non-mounted disk I see no other possibility than to either 1. record all partition UUID's and use that to query for disk catalog entry (meh), or 2. use sudo to retrieve the disk's serial number or UUID.

I would try building a separate volume catalog to track use of specific images maybe, but I don't think that is useful. It is useful to have ``disk check`` work in (non-interactive) situations where there are unmounted volumes (can query with ``/dev/disk/by-uuid/*``)

- TODO: disk catalogue is build/updated on running disk interactively

``.volumes.yaml``::

  disk:
    id: <serial-nr>
    vendor:
    model:
    index: <disk-seq-nr>
    prefix: <mount-basename>
    description:
    [part-UUID: <partition dependent checksum Id?>]

  partition:
    <n>:
      [id: <UUID>]
      [label:]
      host:
      domain:

(or equiv. ``.volumes.sh``)

Above record is mirrored in centralized diskdoc directory at
``$UCONF/user/disk/<disk-id>.sh``
TODO: rename to ``$UCONF/user/disk/<disk-prefix>.sh``

TODO: with ``--no-interactive`` or ``--batch`` don't use ``sudo``

disk
  - depends: jsotk for full regen/update.

  Commands:

  check (default)
    Go over local disks and see that they can be Id'ed.
    When interactive create entries, update properties like host
    or part-UUID. Otherwise just check values.
  status
    Report on last check without redo'ing anything
  enable <device-id>
    load and import data from volume doc
    mount, and create volume symlinks
  load-catalog <device-id>
    copy-fs $1 .volumes.{yaml,sh} /tmp
    import-catalog /tmp/.volumes.{yaml,sh}
    # see if combines with reload-catalog
  mount-tmp (<device-id>|<disk-id>) [fstype]
    ..
  mount (<device-id>|<disk-id>) [fstype]
    ..
  enable-volumes (<device-id>|<disk-id>) [base]
    ..
  copy-fs
    # temp mount, copy file
    mount-tmp $1
    copy $2
  import-catalog <file>
    parse, consolidate settings
  update <dev/disk/part>
    (re)load catalog, check all links for volume or disk with volume(s)
    then update links for volume(s)
  udpate-all
    Run update for every local disk (via /dev/disk).
  check{,-all}
    Dry-run variant of update.

Log
----
- Current disk/card inventaris is in HT, but want something more managable [2016-06-15]
