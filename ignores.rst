
- Ignored filename or directory patterns. Base is directory of dotignore file
  or working directory.

- XXX: Predefined groups for more flexible use, in different contexts.
  Main global groups

- Usage: auto-sets dotfile per main.sh frontend, env: IGNORE_GLOBFILE.
  Load using `ignores_lib_load`, init per `lst_init_ignores [.ext]`.

- FIXME: File should not exist but is populated each execution.
  TODO: move execution (in htd, pd) to {base}_load.

  XXX:
  Standard dynamic initialization from predefined groups and local dir.

- For more dotfiles init allows custom extensions to glob dotfile's name,
  and also preselecting different glob groups per dotfile ext.

  Customizable::

    lst_init_ignores .names global-clean global-purge


Global
  Purge(able)
    Files that SHOULD kept as long as the base is present, but MAY be cleaned
    automatically if desired, e.g. if the base is to be removed.

    The globs should not be used to list files to remove for any clean
    action unless the action is removing the base (checkout, project, etc.)
    Note it can recursively remove entire folders at those times.

    This list may overlap with Clean(able), to indicate files to automatically
    clean each session.

  Clean(able)
    Files that MAY be dropped at any time, but usually kept for a while.
    But SHOULD be cleaned at the end of a user session, failing that
    at the start of a new. These files should not be normally ignored
    in file work flows.

    This does not specify *how* the clean occurs.
    Overlap with other groups MAY specify cleaning workflow.

  Droppable
    Paths respected (ignored and reserved) that SHOULD be handled by
    specific commands, e.g. SCM or IDE, and ignored by commands unless
    specified otherwise. The intent is to give that these may go at any time
    and SHOULD normally be regarded as opaque while they are there.

    Overlap of other groups is allowed to include some files in specific
    workflows, while normally keeping them out of every other command.

    XXX: For most cases it makes no sense, still some commands may need to
    respect reserved names while marking them as per-session (cleanable),
    and/or automatically thrown away?

    This is usefull for a wide range of names, from SCM dotpaths to
    install directories or build-caches.


Htd
  :.names:

  find
    ..
  check-names
    ..

Pd
  ..

