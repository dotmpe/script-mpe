Ignores
========
Filename and path ignore rules from lists of globs and groups of globlists.

Intro
-----
The purpose of the ignores lib is to manage assembling globlists for paths to
ignore when using find, locate and custom scripts. The initial case for it was
to update the SCM ignore file for a checkout, e.g.::

  .gitignore
  .bzrignore
  # etc.

For this case a simple setup of source files was used with distinct groups so
that other scripts could use each for its specific purposes. The main file could
simply be updated by concatenating these local files::

  .gitignore-purge
  .gitignore-clean
  .gitignore-drop

This is still the default lib-init setup (given that ``ignores_prefix=git``).
In addition to these sources, any file ``gitignore/purge.globlist`` found on
`XDG_CONFIG_DIRS` will be used as source for Purgeable file patterns as well
(and Cleanable and Droppable resp.).

But in case of this example, Git has two more options to place globlists which
are very convenient as well (the local ``.git/info/exclude`` globlist and the
``core.excludesfile`` config statement). And those are not managed by
``ignores.lib`` in any way.

Also, there are more uses for globlists. This library just handles two sets:
temporary and tracked files, which are the most important to be able to filter
out from other (user/project) files in shell script workflows.

But using a ``.gitattribute`` inspired scheme, globs can be used to tag and
track or annotate specific file sets with metadata just based on their names.
TODO: meta{,dir}.lib and attributes libs

Different applications may have their own particular sets of
(source/user/project) files.

Usage
-----
Source using User-Scripts lib.lib or User-Conf uc-lib.lib::

  ignores_prefix=my
  lib_require ignores && lib_init ignores

Ensure cache for default groups is updated and copied to main ignore file::

  $ ignores_refresh

With the defaults this should generate ``.meta/cache/myignore-global,local.globlist``,
and copy that to ``.myignore``. That last path is also the value of ``$IGNORES``
and ``$MY_IGNORE``.

Do anything with the main file::

  $ read_nix_style_file "$IGNORES"

  # Or use it
  ignores_do_find
  ignores_do_locate


Use cases
---------
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

Ignore groups
-------------

Global
  Globlist sources for groups outside of current directory.
  A scan on XDG_CONFIG_DIRS for folders names '<prefix>ignore' determines which
  directories are searched.

Local
  Globlist sources inside current directory.

Temporary
  Clean(able)
    Files that MAY be removed at any time, but usually kept for a while.
    These MAY regularly be cleaned.

    This includes temporary files of editors or other processes and certain
    (but not all) cache files. These should be safe to remove on demand to
    cleanup a folder, or for example at user session startup or shutdown.

  Purge(able)
    Files that SHOULD be kept as long as the basedir is present, but MAY be
    cleaned automatically in order to purge it.

    This includes valuable build artefacts and other cache files, which when
    removed would require significant time to regenerate when needed. But which
    would no longer be needed when the entire folder is trashed.

Tracked
  Droppable
    Paths that SHOULD not be handled directly, but are controlled and may be
    safely removable using specific commands.

    This includes local metadata folders for SCM or IDE systems, but also
    checksums and other meta files. Most workflows will want to ignore these
    paths, but they are not invaluable like Cleanable or even Purgeable files.
    Specified paths may contain copies with updates and thus contain state that
    may not have been integrated and distributed yet.

Issues
------
XDG_CONFIG_DIRS is not used correctly.

It is a 'preference-orded set of based directories' and should be used to
lookup preferred copies for config. So, it should be prefixed by a basepath
for each XDG compliant system currently on the stack. For me it is set to::

  /etc/xdg-i3
  /etc/xdg

So perhaps it needs for gitignore these as well::

  $HOME/bin/etc/xdg/xdg-git
  $HOME/.config/xdg/xdg-git
  /etc/xdg/xdg-git

But I think maybe that is where some lib.load or lib.init config file should be
kept.

And introduce new var for globlist lookup, ie.
``IGNORE_INCLUDE=/etc/gitignore:$HOME/.config/gitignore``.

But also allow to include from other sets::

  ignores_prefix=git
  ignores_import=localignore,htdignore


Finally, instances. there is a bunch of parameters

class__Globlist__prefix[id]=git
class__Globlist__basename[id]=ignore
class__Globlist__regenerate[id]=true
class__Globlist__usecache[id]=true
class__Globlist__uselocal[id]=
class__Globlist__groupkey[id]=ignore_groups
class__Globlist__globlistkey[id]=ignores

context_set

ignores_find_files -> ignores_find_expr
ignores_find_expr -> ignores_cat

ignores_cat < @Globlist.globlists

ignores_globlists @{Globlist:-ignores_globlist}_specs

ignores_globlists_specs
  @Globlist.

..
