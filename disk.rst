
Current inventaris docs are in ~/htdocs.
But want something more managable. See 2016-06-15 jrnl.

disk cmd is free so use that. See also ``diskdoc.*``.
Also have some disk handling in htd, consolidated parted parts.


.volumes.yaml::

  disk:
    id:
    alias:
    label:
    description:

  prefixes:

.volumes.sh::

  volumes_disk_id=
  volumes_disk_alias=
  volumes_disk_label=
  volumes_disk_description=

  # XXX:
  volumes_<prefixid>_<attr>=



disk
  depends
    vc? jsotk for full regen/update.

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


