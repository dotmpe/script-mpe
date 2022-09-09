htd catalog
===========
Build file manifest files.

::

    htd help catalog

Objectives
----------
Track contents, and annotate with name, descriptions wrt. type, format, etc.

Keep one unique name per distinct file (stream/contents), or group several files
under one. |---|
Ie. force contents to appear only once, whether as a unique basename or
full-path. Implies other appearances of those exact contents can only be either
an alias (sym/hardlink) or within another file. (and maybe also on/through other
device/special files but those are too undefined for purposes here)

Allow annotation on any path, wether unique basename or full path to local file,
or dir, symlink, etc. One record per unique path, and by default for every file
though some filters will be required there.

TODO: Some help deduplicating is implied. Some practical work wrt. dirs todo.

TODO: maybe track some data at containers first, and then migrate/sort onto
contained entries once checksums are made.
From that follows, maybe annotate tree with include/exclude values


Design
------
- operations on data are done by JSON tools, but data must be YAML formatted

- because the add-file simply appends a YAML list entry (raw) iso. parsing the
  list to JSON, it is not an issue to append an item the catalog (wether
  existing or empty)

Commands
  For simplicity

  - (most) commands accept catalog filename as first argument, and every one
    falls back to CATALOG env.

  - however operations are relative to the basedir of the (first) catalog
    file--paths in the catalog file are relative to the catalog file basedir,
    and not resolved into absolute paths for operations.

Schema
  schema specified in JSON schema, YAML formatted <schema/catalog>
  entries track content streams, ie. files. Considering other types, but how
  to derive keys? Especially need to deal with directories, and/or collections
  of files with local name under one unique catalog name entry.

TODO: Files and other paths
  Basenames are recorded, which means '/' is reserved. Noting is decided on '.',
  it is not requires for uniqueness, and its use is ambigious. ASCII and
  restricted charsets are preferred, but scripts should follow Postel's
  principle wrt. accepting names.

  To record directories, a trailing '/' is used. ({@,|,$,%}-suffixes maybe for
  symlinks,named pipes,devices,character devices etc..)

TODO: Contents
  a list of name-references contained in this one. Ie. an archive, multipart,
  etc. For directories the attribute is redundant and left out.

TODO: Contexts
  Contexts is essentially a list of containers or aliases. The inverse of
  contents. One name can both be in an archive and appear in the unpacked
  directory. Or have other names, aliases, translations, alternate
  organisations, name formats etc.

  How the multiple resulting paths are used or appear is unspecified. Any path
  MAY have a catalog entry, either by name (unique) or full path (local name).

  This can be used too, to record original names without recording them
  individually as symlinks.

Duplicates
  Duplicates never appear in the catalog. Iow. current schema allows one name
  and multiple context for a file with a given checksum. Resolving duplicates
  requires (after hashing) to decide which unique name to keep, and wether to
  amend the contexts list.

TODO: Exists
  A bit to set if the file is unavailable, and it would be impracticle to
  stat/checksum. For example located behind high-latency connection, or
  contained within compressed archive.

Specs
------
See schema/catalog, basicly a list with simple objects. Important keys:

- `name` to document unique name (preferred), or alternatively full `path`
- `keys` to hold any validations tokens, for use with local or remote services
  to validate file beloning to name

- XXX: `attachments`.. in MIME speak a multipart with message and binary
- XXX: `contains`.. a file or a tar, which in turn contains multiple files
- XXX: `categories` to store prefixes, not sure how to deal with these yet.
  Some or only one at a time may exist. Maybe use for overlay filesystem style
  stuff


Use cases
---------

Track files by combination of basename and checksums
____________________________________________________
- Multiple checksums can be tracked tracked, ie. CRC, MD5, SHA1.
- Can de-duplicate filetree if all checksums of certain type have been calculated.
- Having all known checksums makes finding any given file very easy given one or more catalogs.
- Makes tracking older filenames less important.

::

  - name: .empty
    exists: false
    format: empty
    mediatype: inode/x-empty; charset=binary
    keys:
      ck: 4294967295 0
      crc32: 0 0
      md5: d41d8cd98f00b204e9800998ecf8427e
      sha1: da39a3ee5e6b4b0d3255bfef95601890afd80709
      sha2: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      git: e69de29bb2d1d6434b8b29ae775ad8c2e48c5391

Track folders or groups
_______________________
- Folders or groups have no one natural order and therefor no checksums.
- Not all files need to be tracked in individual entries, some may exist as part
  of folders or maybe groups only.

::

  - name: My-Folder/
    contains:
    - index.html

  - name: Group
    members:
    - My-Folder

Recording original name, or previous and alternative names
__________________________________________________________
::

    - name: X-Series.S01E01.tar.bz2
      contains:
      - X-Series.S01E01.tar
      contexts:
      - media/video/series/
      - shared/torrent/complete/X-Series - grp - cam - 768.tar.bz2

Tracking archives, and unavailable files
________________________________________
::

    - name: X-Series.S01E01.tar.bz2
      keys:
        ...
      contains:
      - X-Series.S01E01.tar

    - name: X-Series.S01E01.tar
      exists: false
      keys:
        ...
      contains:
      - X-Series.S01E01/
      contexts:
      - X-Series.S01E01.tar.bz2

Tracking files with non-unique names, and archives
__________________________________________________
::

    - name: X-Series.S01E01.tar.bz2
      contains:
      - X-Series.S01E01.tar

    - name: X-Series.S01E01.tar
      contains:
      - X-Series.S01E01/
      contexts:
      - X-Series.S01E01.tar.bz2

    - name: X-Series.S01E01/
      contains:
      - X-Series.S01E01/screen.jpg
      - X-Series.S01E01/FILE_ID.DIZ
      - X-Series.S01E01/release.nfo
      - X-Series.S01E01/X-Series.S01E01.mkv
      contexts:
      - X-Series.S01E01.tar


This gets quite verbose, but is adequate.
Some space could be saved by encoding
the dirpath prefix for 'dir/' to './' in contents (and ofcourse otherwise
forbidding this).


Issues
------

Checksums
_________
Tracking by checksum is never as easy as it seems.

- algorithms get replaced and will have different performance characteristics

- publishing and processing creates new representations of 'identical' content

- more complex 'fingerprinting' algos may be needed to track content properly

- content is distributed in containers, in different file structures, alongside metadata and other related contents

- cksum has very different results to commonly encountered CRC32's;
  `CRC32 Checksums; The Good, The Bad, And The Ugly`__ gives a good introduction.

  For the three CRC32 variants see `cksum.py` and `test/ck-spec.bats`.

- besides algorithmic differences between libraries, issues with bit
  representation: signed vs unsigned, oct/dec/hex, base64 encoding, etc.

- then there are checksums that include envelopes, ie. git hash-object.
  Or torrent info-hash is an SHA1 of torrent metadata including filenames
  and piece length and count.


See also
--------
- ``ck.lib.sh``, ck.rst
- ``magnet.py``
- rhash offers a fair range of common and more exotic algos, including magnet
  links

.. __: <https://blog.box.com/blog/crc32-checksums-the-good-the-bad-and-the-ugly/>
