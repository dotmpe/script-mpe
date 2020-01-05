htd
  package
    | htd_package_<subcmdid> [ARGS..]
    | package_<subcmdid> [ARGS..]

    Get local (project/workingdir) metadata

  ls
    | package list-ids [ARGS..]

    List local package names

  openurl
    | package open-url ID

    Open local package URL

  run [SCRIPT-ID [ARGS...]]
    ..

  up|down [<host>.]<service> [<Env> [<env>=<val>]]
    TODO: up/down

  res
    ..
  find [ FILE ] [ FRAGMENT ] [ CWD ]
    ..
  process [ LIST [ TAG.. [ --add ] | --any ]
    ..
  doc|documents
    ..
  files
    ..
  `documents <doc.rst>`_
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
        grep_eval='$(git rev-list --all)' htd git-grep golang-builder --dir=/src/github.com/dotmpe/*

    FIXME: cannot simply pass git-grep args. Dir is also not working::

        htd git-grep golang-builder "dev test master" --dir=/src/github.com/dotmpe/*

    1. argument processing is broken, and 2. what if branches don't exist.
    Eval is more practical. But grepping every revision is not::

        repos='/src/github.com/dotmpe/*/.git' \
        grep_eval='$(git br | tr -s "*\n " " ") --' htd git-grep GREP

  archive
    Cabinet dirs and files.

  volumes
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

  scripts
    | htd_scripts_<subcmdid> [ARGS..]

  topics
    | htd_topics_<subcmdid> [ARGS..]
    | topics_<subcmdid> [ARGS..]

    List topics

..
