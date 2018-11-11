
Shell script functions for GIT flow

``vc.lib.sh`` provides plumbing functions for common tasks and checkouts and
repositories, etc. Based on that, vcflow automates up-/downstream rebases or
merges.

Up and downstream branches are recorded in pairs in a text file, and are
committed and distributed.

The aim is to be more efficient and precise, and improve best practices.
For example, a correct setup may be able to rebase (certain) commits and prevent
merges.

Maybe improved checks in hooks can be provided to improve consistency.
Etc.

Flows
_____
To setup a new project::

    mkdir my-project && cd my-project && git init && git add remote ....
    TODO: vcflow new-feature acme-widget
    TODO: vcflow test
    TODO: vcflow hotfix
    TODO: vcflow release
    vc dist

See `package.y*ml <package.rst>`__ for tracking checkouts and repositories
and managing GIT remotes.

After updates the branch changes can be mass merged/rebased downstream,
the result distributed (for CI/CD pipelines)::

    vcflow update-downstream
    vc dist

Up and downstream pairs can be used to show how many commits and which commits
are waiting. XXX: Fast-forward test merges note about conflicts::

    vcflow summary

Local branches can be deleted while they have no local commits while they are
unused::

    vcflow check

Each local branch can be updated from remote::

    vcflow update-local

Commands
________
summary [flow] [Branch]
    Compare branch against all other branches

update-downstream [flow] [<Recurse>=0] [<Cleanup-on-Abort>=1] [<Git-Action>=merge]
    Either rebase or merge, from upstream to downstream branches.
    Recursively to continue updating further downstreams:

    TODO: mark branch pairs 'merge' or 'rebase' per config

check-local-branches
    Check that a flow exists for each local branch

check [flow] [linegrep...]
    Go over up-/downstream pairs and note differences either way: count commits
    available on upstream, commits downstream is ahead.

update-local | update-branches [Git-Remote] [Abort-On-Clean] [Git-Action]
    Update each local branch from its matching remote

    See ``vc update-local``

Plumbing
________
summary-up-down Up-Branch Down-Branch
    Compare number of commits branches have diverged.
