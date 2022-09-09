Htd Log
=======

Write simple or complex structured text into log directories or files. A project
can have one or more locations for logs, and each log can have multiple or a
single type of entry.

Usage:
    htd log list
    htd log edit

Aliases:
    htd [ edit-today | edit-week | edit-month | edit-year | edit-entry ]

See Also:
    ``htd-journal(1)`` ``htd-cabinet(1)``

Intro
------
Using ``strftime(3)`` formatting with ``date(1)`` many variations of log entry
paths and titles can be generated. Days, hours, weeks or months can all be
entries in themselves, be part of enclosing periods or exist in parallel.

For example, depending on preference or context any of these can be a 'day'
entry file location of the same date:

    2020-12-22.txt
    2020/w52/Thursday.txt
    2020/12/22.txt
    2020/12/22/journal.txt

But, day entries can be part of enclosing files, ie. per week, month or year,
or all in one file as well:

    2020-12.txt # 22 December
    CHANGELOG # 2020-dec-22

And 'week', 'month' or 'year' being files, these can be entries on their own.

    2020/Dec.txt
    2020/w52.txt

Design
------
While parsing structured text with shell is not practical, only minimal support
for multiple entries per file is expected. But having a line-, rst- and possibly
md-based format would be useful.

Managing files-as-entries is more practical, we can create symbolic links e.g.
for today, this-sunday or next-month etc., and prepare the hypertext cards for
editing and remove them again if left unchanged or stage them for SCM commit if
filled.

``htd-log(1)`` is a basic frontend for looking at relevant package metadata
and using support functions from ``User-Script:log-htd(7)``.
The ``htd-journal(1)`` and ``htd-cabinet(1)`` frontend have more specific
and usefull workflows.

Specs
-----
The main ``package.y*ml`` item include the 'log' and 'logs' key below which
one or multiple local paths be configured.

Log specification may be structured, or abbreviated string specs.

This gives the following variations in definitions, each of these hase the same
effect:

    log: <pathname> - - .rst # title created default-rst link-week

    log: <pathname>
    logs:
      <pathname>: - - .rst # title created default-rst link-week

    log: <pathname>
    logs:
      <pathname>:
        ysep: -
        msep: -
        ext: .rst
        parts: title created default-rst link-week

But a log might make entries per day in a week-file as well.

    log: <pathname> - .rst - # week-entry


'log' is the primary or default log. The key 'cabinet' may provide the default
archive path.

..
