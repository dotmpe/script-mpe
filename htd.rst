

Spec
----
htd
  up|down [<host>.]<service> [<Env> [<env>=<val>]]
    TODO: up/down

  ls-volumes
    List volumes for local disks, for any services it provides,
    check that a local and global /srv/ path is present.

htd rule-target
  - annotate :case
  - extend

  p:*
    - enables PERIOD
    - provides tdate

    .. scan the source file for the case and its match globs
      these validate any input choice. provides gives the varname

  d:* )
    - enabled DOMAIN
    - provides


Manual
------
On Linux, manual pages are divided into sections:

1. User Commands
2. System Calls
3. Library Calls
4. Special Files (devices)
5. File Formats and configuration files
6. Games
7. Overview, conventions and miscelleneous
8. System management commands

From: Linux Programmer's Manual; man7.org

