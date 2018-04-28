htd catalog
===========
Build file manifest files.

::

    htd help catalog

Design
------
- operations on data are done by JSON tools, but data must be YAML formatted

- because the add-file simply appends a YAML list entry (raw) iso. parsing the
  list to JSON, it is not an issue to append an item to a new catalog
  (null, non-existant list)

For simplicity
  - (most) commands accept catalog filename as first argument, and every one
    falls back to CATALOG env.

  - however operations are relative to the basedir of the (first) catalog
    file--paths in the catalog file are relative to the catalog file basedir,
    and not resolved into absolute paths for operations.

Issues
------
Tracking by checksum is never as easy as it seems.

- algorithms get replaced, new checksums will need to be added

- hashes differ by filters; especially wrt text formats: line-end/tab whitespace
  translation, charset, GIT prefixes data with a type name

- cksum has very different results to commonly encountered CRC32's;
  `CRC32 Checksums; The Good, The Bad, And The Ugly`__ gives a good introduction.

  For the three CRC32 variants see `cksum.py` and `test/ck-spec.bats`.

- besides algorithmic differences between libraries, issues with bit
  representation: signed vs unsigned, oct/dec/hex, base64 encoding, etc.


See also
--------
- ``ck.lib.sh``
- ``magnet.py``
- rhash offers a fair range of common and more exotic algos, including magnet
  links

.. __: <https://blog.box.com/blog/crc32-checksums-the-good-the-bad-and-the-ugly/>
