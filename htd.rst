.. include:: .default.rst

Htdocs
===============================================================================
Prototype commands for processing local site content/structure
_______________________________________________________________________________



Design
------
- Shell. Bourne Shell, prefer compatibility [#]_.
- Python. Node.JS. Perl and other regulars (make, grep, sed, ed, awk, but also moreutils etc.). Ruby. XSLT.
- Data abstraction layer for shell glue in Statusdir_.
- Local metadata through Package_. Working with project packages through Projectdoc YAML/JSON and Projectdir: Pd_.


.. [#] tested, devved on Debian and Darwin/BSD hosts.


Plan
----
TODO: SCRIPT-MPE-1 advanced rules: provide for scheduled and context triggered
rules engine. Ie. a simple cron-esque runner, but also automatic domain network
switch, etc.

Until above requirement is met, htd is a bit of the largest bag in +script-mpe.
And this spec is not actual, but inline htd.sh documentation and structure is
preferred. Should turn lots of comments into proper tasks and more but until
that starts, focus here is on getting SCRIPT-MPE-1 into dev.

But related script/backend work in progress related to below is in Tasks_,
mabye Topics_.

htd process [ LIST [ TAG.. [ --add | --any | --save ] ]
  Process items from list with tag, using any backend found
  for tag.
  Optionally include all items to the tag processor, or add
  items missing the tag before passing to the processor.
  Without tags given, the default is to look up the tags
  for the given LIST.

htd tasks-hub
  Helpers for processing TODO.txt-type lists in ``./to`` dir.


Dev
-------


Issues
-------


Spec
----
htd
  up|down [<host>.]<service> [<Env> [<env>=<val>]]
    TODO: up/down

  process [ LIST [ TAG.. [ --add ] | --any ]
    ..

  ls-volumes
    List volumes for local disks, for any services it provides,
    check that a local and global /srv/ path is present.

  vc
    manage checkouts

  backup
    Move given path argument(s) to local backup annex repo.

    TODO: select path mode from below.

    1. Just a filename;

       - detect base setting, and add prefix. Ie.

          BASE my-xxx-conf /my/dir/to/xxx/config
          cd /my/dir; BACKUP to/xxx/config/file.ini

       - else prefix with cabinet path (<year>/<month>/<day>-<filename>)

    2. A local path to a file;

       - use path elements as tags (require strict format)

       TODO: record trees. See process tags task below.

    3. A directory;

       Replace argument with list of (file) paths below dir.
       Then process as files. (--level[=1] --recurse)

    Options:
        --archive[=tgz] [--archive-base=.] [--archive-name=<cabinet-path>]
          Instead put all path arguments into archive, and cabinet that

        --tags-append=<tag>[,<tag>]
          Create/lookup Ids/tags and append to basename (hyphen separated)

        --add-base[=<dirname .>]
          Add base setting for current dir

        --no-base
          Ignore any base setting; ie. cabinet or store as is

        --no-cabinet
          No cabinet path, leave filename as is if not base setting is found


    TODO: process tags. Look for known tree paths. Goal to cut down on base
    settings, and more uniform entry. Kinda long term goal still.
    TODO: test in sandbox.

  volumes
    ..


  TODO:
    - rename edit -> edit-local
    - edit-main -> edit

  -e|edit [ID]
    Requires search id argument.
    TODO: Without argument, set to local ctx files.
    Opens the EDITOR for the files.

  -E|edit-main [ID]
    Sets arguments to the main Htd script files.
    TODO: Without argument, set to main local source and or document files.
    Opens the EDITOR for the files.

  main-doc|md
    Find and edit (default htd action)

  edit-today|vt
    ..
  edit-note
    ..
  edit-note-nl|nnl
    ..
  edit-note-en|nen
    ..
  (todotxt edit)|tte|todotxt-edit
    ..
  edit-rules
    ..
  edit-test
    ..
  inventory|inventory-electronics ID
    edit inventory main or ID

  git-files
    ..
  git-grep
    Examples::

        verbosity=6 \
        grep_eval='$(git rev-list --all)' htd git-grep golang-builder --dir=/src/github.com/bvberkum/*

    FIXME: cannot simply pass git-grep args. Dir is also not working::

        htd git-grep golang-builder "dev test master" --dir=/src/github.com/bvberkum/*

    1. argument processing is broken, and 2. what if branches don't exist.
    Eval is more practical. But grepping every revision is not::

        repos='/src/github.com/bvberkum/*/.git' \
        grep_eval='$(git br | tr -d '*\n ' ' ') --' \
            htd git-grep golang-builder



htd rule-target
  - annotate :case
  - extend

  p:*
    - enables PERIOD
    - provides tdate

    .. scan the source file for the case and its match globs
      these validate any input choice. provides gives the varname

  d:* )
    - enabled DOMAIN
    - provides


Manual
------
On Linux, manual pages are divided into sections:

1. User Commands
2. System Calls
3. Library Calls
4. Special Files (devices)
5. File Formats and configuration files
6. Games
7. Overview, conventions and miscelleneous
8. System management commands

From: Linux Programmer's Manual; man7.org
