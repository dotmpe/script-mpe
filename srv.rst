srv - Service containers

Goal
----
Mapping of volume folders to unique paths, maintain those paths locally, and
track and relate all names and containers in SQL.

Objectives:

1. Unique paths for all service volume instances independent of host,
   and closely associated global ID's for the actual storage volumes (ie.
   'disks') and other service volumes.

2. One local default service volume instance per host, easily switchable to
   another volume.

3. Tracking of basic lifecycle for service volumes and how to interact with
   service container.


Design
------
The ``/srv`` directory prefix is claimed, to become a basepath for all service
volume instances.

According to the LHS, ``/srv`` [#]_:

1. should exist,
2. should make no assumptions about subdirectory structure,
3. should contain "site-specific data which is served by this system", and is
   for users to "find the location of the data files for particular service".

Most names will be symlinks.
Iow. the ``/srv/`` path name will be an alias for another, actual local host
path.

Syntax
______
Contrary to point 2 above, in addition to service container name, three other
name types are claimed: Disk-ID, Hostname and Domainname. None of these appear
alone, but ``srv`` will be setup to take control of names with the following
pattern:

- <name>-<alias>
- <name>-<disk-id>-<host+domain>

All names should conform to ``[a-z_][a-z0-9_]*``. Hyphen is reserved as
separator. Other chars could be allowed but I see no good reason currently.
Some string handling is required. But ie. host and domain name should usually
be literally equivalent to the system reported version.
The service container name should be equally conservative.

Root FS Disk ID
_______________
The Disk ID is a concatenation of two numbers, a unique integer to identify a
physical disk, plus one for a partition on that disk. The latter should
correspond to the partition table, and the former is probably a sequential
counter too. However the exact mapping, and tracking of this data is out of
domain for srv. As far as srv concerned, the FS root is just another service
container called 'volume'.

Predefined tags:

- local - an alias to make one local os path that points to a default storage
  for a service container
- volume - an alias for a FS root dir, ie. these are or link to a mount point
- annex -
- src
- project

Domains?
local
public
private
home
work


The emergent patterns are these three types of symlinks::

  <sub>-<disk-id>-<host+domain> -> <super>-<disk-id>-<host+domain>/<sub>

  <sub>-<alias>                 -> <sub>-<disk-id>-<host+domain>

  <sub>-<disk-id>-<host+domain> -> <super>-<alias>/<sub>


But neither a single level-down nor a matching sub-name is required for the
first or third symlink. It would allow for autodiscovery, and monitoring of all
volume root folders though.

Also the third type may be questionable.

These need not to be symlinks, except that if they are anything but
a mount we need to know about which 'volume' they eventually end up on.
But 'volume' instances could be mounted directly into /srv, onto the 'volume'
paths and the system would still be structurally sound.

We don't want too much assumptions about volumes, disks and partitions though,
since we can easily find new sorts of stores that don't cleanly map to disk
volume/partition numbering schemes, and even for regular hardware these may get
dissasociated by RAID, LVM or other virtual mapping schemes with various
purposes.

In general, we can see the names as being suffixed by one or two tags that
identify a group, or level in some hierarchy. And we do this to track

- Disk ID - a combination of ID for medium and ID for virtual store on that
  medium.
- Host + Domain - a second combination but with a global ID at another level.
- Alias -


Use Case
--------
A most basic use case well suited for illustration is the distribution and
access to backups. Backups may come as tombstone-esque blobs that archive
delta's for some subsystem, or be mirrors of file copies. And anything
in between.

Whatever the case, its physical location and number of instances is important.
Ie. keeping two backups at the location probably defeats most common backup
use-case requirements. Instead for sake of this use case lets require at most
one backup folder per disk, have at least three copies, and get access anywhere
iot. synchronize them.

Using ``srv`` we reserve a new name, 'backup'. Next, we make instances at
strategically chosen locations. Say we have four disks, and seven usable FS
roots at some given box. Two disks are local, one has the OS's root FS,
another an USB stick and the rest remote mounts.

So we want srv to scan the mounts, recognize some basic metadata and have setup
the following symlinks for us in ``/srv`` to build upon::

  volume-1-1-laptop-mydomain -> /boot
  volume-1-3-laptop-mydomain -> /
  volume-1-4-laptop-mydomain -> /mnt/second-partition
  volume-2-3-laptop-mydomain -> /media/usb0
  volume-3-4-vs1-mydomain -> /mnt/remote-mount-1
  volume-4-1-vs2-mydomain -> /mnt/remote-mount-2
  volume-4-3-vs2-mydomain -> /mnt/remote-mount-3

You see we have a unique 'volume' per available "physical" storage. The actual
metadata resolving is again out of domain for srv (see disk.sh, and package.rst).

Next we can easily choose to put backups at our laptop, and at each of the remote
virtuals::

  backup-1-4-laptop-mydomain
  backup-3-2-vs2-mydomain
  backup-4-3-vs2-mydomain

The names reflect all the information on the actual location we would
need for further tracking. E.g. making sure that 'backup' instances appear at
most once per disk. Or maybe that a certain backup will not appear in some
domain, for legal reasons or to reduce potential attack vectors for example.

Looking at the actual symbolic references we see the pattern even more clearly.
::

  backup-1-4-laptop-mydomain -> volume-1-4-laptop-mydomain/backup
  backup-3-2-vs2-mydomain -> volume-3-2-vs2-mydomain/backup
  backup-4-3-vs2-mydomain -> volume-4-3-vs2-mydomain/backup

Also we introduce our first alias 'local' which gives us one symbolic path
for the 'backup' service that can be configured per host::

  backup-local -> backup-1-4-laptop-mydomain

Its reasonable in this imaginary use case to have a backup service running per
host. And that we want a simple name to put into its configuration. So we make
this symlink, which can tell us all about the identity but to the service is a
simple descriptive path that is same for every host. And it can be changed in a
determened fashion, if we know about the backup service conainer's lifecycle
(ie. can shutdown/reload it while we change the symlinks target).



.. [#] http://www.tldp.org/LDP/Linux-Filesystem-Hierarchy/html/srv.html
