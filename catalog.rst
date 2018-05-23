htd catalog
===========
Build file manifest files.

::

    htd help catalog

Objectives
----------
Track contents, and annotate with name, descriptions wrt. type, format, etc.

Keep one unqiue name per distinct file (stream/contents), or group several files
under one. |---|
Ie. force contents to appear only once, wether as a unique basename or
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

Use cases
---------

Tracking existing and unavailable file name/metadata
____________________________________________________
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


Recording original name, or previous names
___________________________________________
::

    - name: X-Series.S01E01.tar.bz2
      contains:
      - X-Series.S01E01.tar
      contexts:
      - media/video/series/
      - shared/torrent/complete/X-Series - grp - cam - 768.tar.bz2



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


This gets quite verbose, but is adequate. Some space could be saved by encoding
the dirpath prefix for 'dir/' to './' in contents (and ofcourse otherwise
forbidding this).


Issues
------

Checksums
_________
Tracking by checksum is never as easy as it seems.

- algorithms get replaced, new checksums will need to be added

- hashes differ by filters; especially wrt text formats: line-end/tab whitespace
  translation, charset, GIT prefixes data with a type name

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
- ``ck.lib.sh``
- ``magnet.py``
- rhash offers a fair range of common and more exotic algos, including magnet
  links

.. __: <https://blog.box.com/blog/crc32-checksums-the-good-the-bad-and-the-ugly/>
