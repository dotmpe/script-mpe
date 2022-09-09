Htd-Journal(1)
==============

Based on ``htd-log(1)`` prepare and edit 'day', 'week', 'month' and 'year'
entries. Add or update parts of entry cards with ``User-Script:rst-doc(7)``,
including links to next/prev item in sequence or enclosing periods. As well as
generate lists of entries per period.

Usage:
    | htd journal edit

Intro
-----

Design
------

edit-today
Edit todays log: an entry in journal file or folder.

If argument is a file, a rSt-formatted date entry is added. For directories
a new entry file is generated, and symbolic links are updated.

TODO: accept multiple arguments, and global IDs for certain log dirs/files
TODO: maintain symbolic dates in files, absolute and relative (Yesterday, Saturday, 2015-12-11 )
TODO: revise to:

- Uses pd-meta.log setting from package, or JRNL_DIR env.
- Updates symbolic entries and keys
- Gets editor session
- Adds date entry or file boilerplate, keeps boilerplate checksum
- Starts editor
- Remove unchanged boilerplate (files), or add changed files to GIT
'


Specs
-----

..
