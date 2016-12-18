finfo
  finfo.py [options] [--env name=VAR]... [--name name=VAR]... (CTX|FILE...|DIR...)
    ..

  finfo.py
    - Sets arguments to CWD.
    - Prints all paths, normally not ignored.

    TODO: contexts for ignore but want to keep it flexible. SCM, clean, user
    customized groups.

  finfo.py --auto-prefixes

    list prefixed paths
    - TODO: get a blank cllct.rc for testing. And SA test worktree.



  - Paths are grouped (prefixed) in user named directories.

  - The user home directory is named 'home', or '~user' for local and global
    usage.

  - Depending on the host OS, there are one or more filesystem roots.
    TODO: `diskdoc` to get more names; volume mount points, services?

  - XXX: schemes to discover the name for a foreign dir/volume/disk/archive


