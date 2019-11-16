Treemap
=======

The following diagram shows a filetree which squares build from all the files, using colors for different directories.
It required an XML like structure, and the script was borrowed from http://bl.ocks.org/mbostock/4063582.

There is no interaction.

.. raw:: html

        <iframe src="treemap/1.html" marginwidth="0" marginheight="0" scrolling="no"></iframe>

----

Another treemap-like diagram shows another representation of the filetree in JSON as a navigable, top-down tree structure.
It does seem to render something, but the JSONs are different:
`JSON </project-treemap.json>`_
http://bl.ocks.org/mbostock/raw/1005873/readme.json
Borrowed from <http://bl.ocks.org/mbostock/1005873>.

.. raw:: html

        <iframe src="treemap/2.html" marginwidth="0" marginheight="0" scrolling="no"></iframe>

----

- See also `other D3 scripts <d3.rst>`_

-----

Design
------
See ``treemap.py`` and ``treemap2.py``.
Testing setup in ``treemap3``

- Relational DB hacking in treemap2
- Real dicts/lists in treemap3

Plan
----
- Build complete trees with `fs:{{dir,file,}node,}`
- Record key paths in treeinfo

Specs
-----
treeinfo `~/.local/var/treemap/__info__.pyp`::

    <vol-id>:
        <path/base>:
            ctime:
            mtime:
            file-count:
            content-size:
            ..
            file-size:
            name-size?:
            symlink-size:

tree `<path/base>/.cllct/treemap.pyp`::

    name:
    entries: []
    mode:
    content-size:

- TODO: add versatile caching treemap3

  JSON metadata storage

  --cache-count x
  --cache-threshold yM     Start writing <basedir> size.int or json at x files, y megabytes
  --(no-,)auto-cache       Turn on/off default count/threshold

  size
    report on size for dir (--update to write existing local and/or user-caches,
    --init to write metadata to local <basedir> cache, else store in userhome)
    should not write <basedir> if <projdir> cache, user-cache idem ditto (unless
    --copy)
  info
    generic info for path (or homedir caches?)
  check
    errext on ood-cache
  update
    defer to size with --update

  Metadata Paths

  --checksum-paths to anonymize metadata

  - <basedir>/.cllct/treemap.json
  - <basedir>/.cllct/treemap/content-size.int

  * ~/.local/var/cllct/treemap/<dir>.json

  * ??? <projdir>/.build/treemap/<dir>.json

  More cases:

  - --rewrite all from/to anonimized
  - --drop those outside changed count/threshold
  - --copy user from local <basedir> or <projdir> caches (for removable media)

  XXX

  - --auto re-use local build caches, --auto-cache, and copy projdirs or
    basedirs for volumes marked removable.

Updates
-------
2019-04-19
    basic size, count routines done in treemap3; simple and using nodes:
    ``fs_{{dir,file,}node,}``

..
