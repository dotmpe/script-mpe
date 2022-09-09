.. include:: ../.default.rst

Documentation Index
-------------------

Main docs
_________
`Htd`_
  accummulates all the rest ad-hoc user-scripts (10K lines,
  working to get it down).

- `Project`_ high level discussion on essential devops. `Build`_ specifics.
- `Package`_.

Pd: pdoc and pdir
  Track and manage projects. Getting very stale as ``htd package`` and
  Build_ progress further.

  - top-level `dev <../projectdir.rst>`_  and `specs <./feature-pdoc>`_ doc
  - feature and `test <../test/pd-spec.rst>`_ writeups

Other
______
`Features`_ [2016]
  Some thoughts on how to document/structure/track features, components under
  test.

`Workflow`_ [2011]
  Thoughts on personalized task, time-tracking workflow tooling

------------

Other older docs on components in script:

`Resourcer`_
  rsr stuff on low-level tooling, convention

- `Taxus <./feature-taxus>`_
- `finfo <../test/finfo-spec.rst>`_
- `treemap <../treemap.rst>`_
- `vc <../vc.rst>`_
- `todo <../todo.rst>`_
- `Tasks`_
- `bookmarks <../bookmarks.rst>`_
- `box <../box.rst>`_
- `calendar <../calendar.rst>`_
- `disk <../disk.rst>`_
- `docopt <../docopt.rst>`_
- `esop <../esop.rst>`_
- `jsotk <../jsotk.rst>`_
- `matchbox <../matchbox.rst>`_
- `Statusdir`_
- `d3 <../d3.rst>`_


- `Working on projects`__, a 2011 sketch about working on projects
  privately or professionally, ideas on tooling support.

GIT Branches
  master
    Main branch, all branches should follow.

    dev
        Unstable.

        Focus is on building various command line handling frameworks with
        increasing level of integration and consequently implementation
        requirements.

        Need work on ways to increase coupling while keeping functionality stable.
        See test branch.

        Various topics branch here into ``dev_*`` prefixed branches.

        dev_taxus
            Working to reintegrate ideas from old ``dev_`` forks into dev,
            currently concerning libcmd functionality and txs.Txs with subclasses.

        dev_confparse_hier
          Testing confparse with inherited properties and hierarchical src file
          tree. Need to keep test cases alive here.

    test
        Writing and running tests.
        Should follow dev before master reintegration.

Scripts
  radical
    tracking tagged source comments (TODO, FIXME, et al.).
    Scan for tags in comments of source-code and \*NIX-style text-files.
  cabinet
    WIP: archive files and query
  domain
    WIP: host/nfs/nslookup switching based on current network
  dtd2dot
    WIP: preliminary DTD tree to GraphViz_ DOT graph generator
  fchardet
    detect file encoding
  ffnenc
    recode a file from one encoding to another
  fsgraph
    filesystreem tree to GraphViz_ DOT graph
  mapsync
    rsync wrapper
  msglink
    find and symlink to message file in Maildir_
  nix-rename
    try to rename files to not contain metacharacters (ie. ``[^a-z][^a-z0-9]*``)
  py-MRO-graph
    generate inheritance hierarchies for Python (broken)
  pathlist2dot
    generic path to GraphViz_ DOT graph generator
  relink
    rewrite symbolic link targets using regular expression
  snip
    extract spans from files based on translit identifiers (see `Transliterature
    Project`_)
  transquote
    print N3 for translit_ data (using transquoter)
  update
    update any GIT, Bazaar, Subversion or Mercurial working trees beneath the
    current directory

Libraries
  The following modules have no executable interface.

  confparse (std python)
    parse settings from yaml

Configuration
  cllct.rc
    Global metadata file with settings shared by scripts and experimental
    projects. Default: ~/.cllctrc. This file is rewritten so it may be
    convienient to a separate copy for manual editing.

  cllct
    Per volume metadata directory.



.. _graphviz: http://www.graphviz.org/
.. _maildir: http://en.wikipedia.org/wiki/Maildir
.. _Transliterature Project: translit_
.. _translit: http://transliterature.org/
.. __: https://github.com/dotmpe/script-mpe/blob/master/WorkFlow.rst
