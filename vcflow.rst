
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


..

    NOTE: The setup is generic, but for certain functions may be missing still.
    Only GIT is supported.
