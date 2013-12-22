script.mpe
==========
Various tools and ongoing experiments that have not yet deserved their own
project.

See 'main.py' for an integrated approach to the tooling.

Documentation
  - `Working on projects`__

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
			Working to reintegrate old ``dev_`` forks into dev.

    test
        Writing and running tests.
        Should follow dev before master reintegration.

Design
  Cmd
    build
      co
        ..
    clean
      ..

  Cmd (no-op)
    info
      stat [default]
        dmk
          ..
        dep
          ..
    test
      ..

Scripts
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
    try to rename files to not contain metacharacters (ie ``[^a-z][^a-z0-9]*``)
  py-MRO-graph
    generate inheritance hierarchies for Python (broken)
  pathlist2dot
    generic path to GraphViz_ DOT graph generator
  radical
    tracking tagged source comments (TODO, FIXME, et al.)
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
.. __: https://github.com/dotmpe/script.mpe/blob/master/workflow.rst

