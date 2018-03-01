
Shell script functions for GIT flow

``vc.lib.sh`` provides plumbing functions for common tasks and checkouts and
repositories, etc. Based on that, vcflow automates up-/downstream rebases or
merges.

Up and downstream branches are recorded in pairs in a text file, and are
committed and distributed.

The aim is to be more efficient and precise, and improve best practices.
For example, a correct setup may be able to rebase (certain) commits and prevent
merges. Maybe improved checks in hooks can be provided to improve consistency.
Etc.


Flows
_____
update-downstream [gitflow.tab] [<Recurse>=0] [<Cleanup-on-Abort>=1] [<Git-Action>=merge]
    Either rebase or merge, from upstream to downstream branches.
    Recursively to continue updating further downstreams:

    TODO: mark branch pairs 'merge' or 'rebase' per config

check-local-branches
    Check that a flow exists for each local branch

check [gitflow.tab] [linegrep...]
    Go over up-/downstream pairs and note differences either way: count commits
    available on upstream, commits downstream is ahead.

update-local | update-branches [Git-Remote] [Abort-On-Clean] [Git-Action]
    Update each local branch from its matching remote

    See ``vc update-local``
