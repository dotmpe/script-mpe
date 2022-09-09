File and path ignore rules

- Ignored filename or directory patterns. Base is directory of dotignore file
  or working directory.

  The goal is to sort all file content until everything is tracked by some
  system or workflow. The ignores combined with lst should provide the base
  framework to do that, for ignores itself it builds on GIT ignores to
  help to keep these files out of GIT and ignore their status.

- global/local/project gitignore keeps files out of SCM.

  And also away from ``git clean -df`` but in reach of ``git clean -dfx``,
  only repositories are left, which ``git clean -dffx`` also removes.

- Ignores can have other contexts than SCM. Untracked files may be tracked
  by other systems, both for prerequisites as build results.

  E.g. binary builds may be tracked. Package managers may have local caches,
  third-party libs and installs.

- Little is clear about the lifecycle, since there is no overarching workflow.
  Use a htd/pd workflow and project lifecycle, we get distict states and
  can assign a meaning to our ignore lists based on the point where it is used.

  Purgeable before reset or disable. Cleanable to reset the project to a
  known stat, same as after init.

- Usage: auto-sets dotfile per main.sh frontend, env: IGNORE_GLOBFILE.
  Load using `ignores_lib_load`, init per `lst_init_ignores [.ext]`.

- FIXME: File should not exist but is populated each execution.
  TODO: move execution (in htd, pd) to {base}_load.
  XXX: Standard dynamic initialization from predefined groups and local dir.


Global
  Clean(able)
    Files that MAY be dropped at any time, but usually kept for a while.
    But SHOULD be cleaned at the end of a user session, failing that
    at the start of a new. These files should not be normally ignored
    in file work flows.

    This does not specify *how* the clean occurs.
    Overlap with other groups MAY specify cleaning workflow.

  Temp(orary) or Purge(able)
    Files that SHOULD be kept as long as the basedir is present, but MAY be
    cleaned automatically if desired with no harm except some runtime
    (reinit/reinstall/rebuilt) costs. E.g. if the base is to be removed or to
    reset it.

    The globs should not be used to list files to remove for any clean
    action. Unless the action is removing or resetting the base (checkout,
    project, etc.)
    Note paths listed as purgable can recursively be removed in an instant.

    This list may overlap with Clean(able), although Cleanable is considered
    independently and/or before Purgeable anyway. Iow. these items should be
    migrated to the Purgeable listing.

  Droppable
    Paths respected (ignored and reserved) that SHOULD be handled by
    specific commands, e.g. SCM or IDE, and ignored by commands unless
    specified specifically otherwise.

    The intent is that these may go at any time, but SHOULD do so by a dedicated
    tool and/or workflow. Normally they regarded as opaque while they are there
    and not part of source files.

    Overlap of other groups is allowed to include some files in specific
    workflows, while normally keeping them out of every other command.



Htd
  ignore-names:
    ..
  check-names
    ..
  find
    ..

Pd
  ..

