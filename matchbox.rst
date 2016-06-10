Matchbox
========
:Created: 2015-08-10
:Updated: 2016-03-12
:Version: 0.1


Intro
-----
Filename parsing and renaming command-line tool, based on plain-text filename templates and
template placeholders::

  $ matchbox.py check-name ANSI-shell-coloring.py
  OK filenames-ext,python-script,std-ascii ANSI-shell-coloring.py

Checks a local table and returns any matching templates, or an error for none.
The table is a simple text file to specify globs to match, templates for parsing/renaming and tags to name the file-sets. For example two lines from `table.names`::

  *.py @NAMEPART.@EXT python-script
  *.py @IDCHAR.@EXT python-module

The template placeholders are defined as Basic Regular Expressions [BRE] in `table.vars`,
in a shell-script compatible file.
Matchbox is a Python implementation, it rewrites the BRE's for use with Python `re`.
Some shell-scripts are in `match.sh`.

Another example parsing::

  $ matchbox.py match-name-vars ANSI-shell-coloring.py filenames-ext
  # Loaded /Users/berend/bin/table.vars
  # Compiled pattern to '^(?P<NAMEDOTPARTS>[A-Za-z0-9\._-]{1,})\.(?P<EXT>[a-z0-9]{2,5})$'
  # NAMEDOTPARTS      EXT
  ANSI-shell-coloring py

More single-name parser commands::

  matchbox.py check-name NAME [TAGS]
  matchbox.py match-name-vars NAME TAG_OR_NAME_TPL

Matchbox is more useful as a shell-script pipeline, to rewrite lots of files.
The following commands read names per line from standard-input::

  matchbox.py check-names [TAGS]
  matchbox.py match-names-vars NAME_TPL
  matchbox.py rename FROM_TPL TO_TPL [EXISTS [STAT]]

Other commands::

  matchbox.py show
  matchbox.py dump


Changelog
---------
Version 0.1 flow.

- Read input strings (filenames or any text lines) from standard-input.

- Load BRE name/pattern pair definitions from .vars files. For example::

    match_EXT='[a-z0-9]\{2,5\}'
    match_NAMEPART='[A-Za-z_][A-Za-z0-9_,-]\{1,\}'

  This is compatible with shell-script variables and some other formats for interoperability.

- Match and parse using regular expressions build from named
  Basic Regular Expressions parts, arranged into a `name-template`,
  and compiled into a Py re::

    $ matchbox show_name_regex @NAMEPART.@EXT
    ^(?P<NAMEPART>[A-Za-z_][A-Za-z0-9_,-]{1,})\.(?P<EXT>[a-z0-9]{2,5})$

- Supplement parsed data (to add defaults, env values, etc.) for certain
  'special' tags (ie. filesize, encoding, format or content-type).

- Simply reorder 'tags' (the BRE match-group name) to rewrite names,
  adding, merging or removing tags. E.g.::

    $ matchbox rename @NAMEPART.@EXT @NAMEPART.old.@EXT < echo my-file.txt
    my-file.txt -> my-file.old.txt

    $ matchbox rename @NAMEPART.@EXT @SHA1_CKS-@NAMEPART-@SZ.@EXT < echo my-file.txt
    my-file.txt -> a8fdc205a9f19cc1c7507a60c4f01b13d11d7fd0-my-file-3.txt



Dev
---

- TODO: inherit tables, extend each table with rules found along path to allow
  for global and local rules.

  - TODO: manage named BRE through subcmds, add some layer to deal with inherited
    and/or set-based name tags.

- TODO: add shell-program resolver, and subcmd to rm/add resolved tags+cmds.

- XXX: tables provide indices and maps for path instances,
  should integrate with metadata efforts. Iow. start to record some kind of
  class or mode statements.

- XXX: table.* allows for interop with native Sh, perhaps other interpreters.
  vars holds match_<group>, BRE patterns. Table names holds globs and tag
  templates, possibly more tags.

- XXX: files in dir should match at least one pattern from table.names.
  Such rules are always subject to a sequence. tags may be used to differentiate
  results.

- FIXME: want to use docopt(-mpe) but need to fork confparse code into proper project
  also. Same for output writing: want to reduce deps, not increase AND also KISS.

- Only basenames are dealt with yet. But the same mechanisms apply for deeper
  file sets. Need to deal with prefixes.

