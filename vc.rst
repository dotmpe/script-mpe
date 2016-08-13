Bourne Shell Version Control Wrapper
====================================

Deal with SCM checkout directories. GIT.


UI
--
vc
  state
    TODO: (Re)set or get mode of checkout. Available modes correspond to ... vc rules.

  excludes
    List local ignore patterns. Includes temp-patterns and cleanables.

  temp-patterns
    Patterns for untracked paths that can be removed regularly, without requiring
    explicit reinitialization. This may include temporary files that are
    currently in use.

  cleanables
    Patterns for untracked paths

    can be automatically removed, and


Local var util::

  print-all <path>


State
-----
TODO: keep per repo.

:status: current bits and flags of checkout
:use-mode: [ none | open |
:clean-mode: TODO: see Pd. [ tracked | untracked | excluded ]
:sync-mode: TODO: See Pd.

Use Mode
  none
    Track normally. (No changes or untracked files expected.
    Stash should be empty) XXX: check sync?
  open
    Files may be in use.
  wip
    Files are being changed. There may be staging or stashing.
  checkin
    Files may be staged, but not untracked. No stash.
  close
    Like none, but also check sync.


Paths
-----
Untracked
  Everything not checked into SCM, excluded ignored files. [uf]

Excluded
  Ignored untracked files. Paths always kept out of version control.

All untracked need to be cleaned before disabling and removing the checkout.

Temporary Files
  Paths created during use that can be removed safely while not in use.

Cleanable Files
  Files created on initialization, or during use that should be kept.
  For files that need explicit regeneration, and/or those that should be
  present while the checkout is in use, until it is removed.

Applies to untracked files. For tracked files similar semantics?


Patterns
--------
Ignores
  Patterns to untracked paths, never checked into SCM. Unversioned files [uf].
  Usually includes backup, swap and other cached or temporary files but can
  also include builds, packages and other generated content or distributions.

  GIT
    Local ignore rules are in .gitignore and .git/info/excludes.
    Global rules can be defined in GIT config.

    Extension: vc regenerate rebuilds the local exclude list from .gitignore-*
    files. For .gitignore-{temp,clean} see temporary and cleanable files resp.


Rules
-----




