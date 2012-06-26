script.mpe
==========
Various tools and ongoing experiments that have not yet deserved their own
project.

Documentation
  - `Working on projects`__

GIT Branches
  master
    Main branch, topic branches  eventually reintegrated here

    dev
        ..
    test
        Writing and running tests. Main devel at dm.

Wanted
  search
    Plain and simple.
  worklog
    Show active tasks, start and stop sessions bound to selected resources, 
    log notes.
  catalog
    Move content onto one of the permanent volumes,
    requireing certain organizational metadata.
  archive
    Put (personal) content away in encrypted archives, but keep some metadata.

Main
  rsr
    - Basic local file management: consolidation, tagging, metadata.
    - Per-user object storage in shelve, data indexes in anydbs.
    - Volumes separate segments of the file space.
  taxus
    Relational database for distributed metadata, distributed addressing of
    data (multi-user/host filespace).
  lind
    Interactive frontends to rsr and taxus.
  workLog
    Interactive work session manager with timing.
  radical  
    - tracking tagged source comments (TODO, FIXME, et al.)
      TODO: Tagged comment and embedded sentinel manager for 
      inline file annotation and resource linking.
  gate
    - Resource registration and lookup mechanisms.
    - Content negotiation.

Libraries
  confparse (std python)
    parse settings from yaml

Unsorted
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

Configuration
  cllct.rc
    Global metadata file with settings shared by scripts and experimental
    projects. Default: ~/.cllctrc. This file is rewritten so it may be
    convienient to a separate copy for manual editing.


  cllct
    Per volume metadata directory.


.. _graphvix: http://www.graphviz.org/
.. _maildir: http://en.wikipedia.org/wiki/Maildir
.. _Transliterature Project: translit_
.. _translit: http://transliterature.org/
.. __: https://github.com/dotmpe/script.mpe/blob/master/workflow.rst

