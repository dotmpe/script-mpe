


Spec
----
TODO: SCRIPT-MPE-1 advanced rules:

htd
  up|down [<host>.]<service> [<Env> [<env>=<val>]]
    TODO: up/down

  ls-volumes
    List volumes for local disks, for any services it provides,
    check that a local and global /srv/ path is present.

  init-backup-repo
    Create local backup annex repo (/srv/backup-local in /srv/annex-local).

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


