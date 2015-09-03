script.mpe
==========
:Version: 0.0.0+20150823-1856

Build-status
    .. image:: https://secure.travis-ci.org/dotmpe/git-versioning.png?branch=test
      :target: https://travis-ci.org/dotmpe/git-versioning
      :alt: Build


Various tools and ongoing experiments that have not yet deserved their own
project.

Test
    ::

       ./test/*-spec.bats

See also `.travis.yml`.




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

    test
        Writing and running tests.
        Should follow dev before master reintegration.


Documentation
  - `Working on projects`__, a 2011 sketch about working on projects
    privately or professionally, ideas on tooling support.


Scripts
  radical
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

Change Log
----------
2008
    Seperate project created for all scripts on my $PATH, 
    previously in my private dotfile repository.
2012
    Have had various mostly imcomplete projects involving 
    Python command-line tools. Focus moves to this project
    to build sharable code for the problems of interest,
    most specifically file and resource metadata management.
2013 
    Various scripts are still unused in daily sysops.
    Moved to create a single frontend which is too ambitious while other
    shared code is still immature.

    Started using testing and looking at Zope Component Architecture to improve 
    program stability during project development.
2014
    Planning to continue to improve confparse and libcmd, split those off,
    see how that works for other projects. 

2015
    Now using htd, vc, dckr and other scripts only mostly.
    Stopped dev on most python scripts, but for now and then.


.. _graphviz: http://www.graphviz.org/
.. _maildir: http://en.wikipedia.org/wiki/Maildir
.. _Transliterature Project: translit_
.. _translit: http://transliterature.org/
.. __: https://github.com/dotmpe/script.mpe/blob/master/WorkFlow.rst

