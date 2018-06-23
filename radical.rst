Radical scans files and directories for commented lines with TODO/FIXME/XXX or
other tags.

It uses simples regexes for this, and provides full character and line offset
information with the extracted data so that other programs can choose to rewrite
those parts. Without any significant knowledge about the source format.

Printing is done in some various initial formats. Examples::

    $ radical.py -u full-id ./res/
    [...]
    ./res/lst.py:1953-1990;lines=80-80;flavour=unix_generic;comment=1954-1991

    # todo.txt:
    TODO: give access to lookup indices  @./res/lst.py line:80-80

    # grep:
    ./res/lst.py:80:  TODO: give access to lookup indices\n

    # id:
    ./res/lst.py:1953-1990

    # full-sh:
    :./res/lst.py:80-80:1952-1989::::  TODO: give access to lookup indices\n


These spanpointers are directly inspired by transquoter.py, and the Udanax
project. Using these in streams as a protocol for edit operations enables other
shell scripts to work on file and web based stream content in new ways (but only
on decoded literal text in this case).

It is the first step for content to migrate naturally between files, and to keep
tracking it while it is "copy/paste"'d.
However for versioning and editing a specialized backend and frontend is needed,
capable of doing 'enfiladics'. For the backend this means dealing with storage
of and queries on linked tree structures or similar complex tasks. For the
frontend it means all edit operations must be expressed in pre-specified
commands, and operate on absolute or relative ranges of text. Only when the
session is formalized like this can it track content moved around within the
document, from elsewhere, and what was removed or typed into it.

Read more on Ted Nelson's `Transliterature, A Humanist Design <http://transliterature.org/>`_.


Design
-------
Radicals initial routines have had one major refactor, but not all features and
old code are cleared up yet.

Radical and some initial backend code are in 'radical*py'. It is tested with a
Python and BATS unittest case. Most of its docs are inline Python docstrings.
No installer. No guide or usage for DB setups.


Issues
------
Currently it does not catch every tag, but only those within recognized
source-code comment formats.

For docstrings or documents this implementation cannot find a range delineating
the comment to extract the description part from. Adopting additional syntax is
not an objective, but specifying how to identify and mark embedded tasks is.

The exact tag format is not cut in stone either, as all scans are user
configurable regular expressions.


Matching
________
`radical.py` has these requirements for the inital tag match:

- A leading space, or start of line
- The tag itself
- Optional ID for the task
- Trailing space to separate from task description following

With a match, the exact locations of the tags are known and theoretically can be
overlayed on the ranges of comments or other native structures. However for now
instead a reverse/forward scan using the comment matching regexes is done.

The expression allows for either a numeric ID (and use of spaces), or an ID
using characaters (but not spaces). That prevents the use of numbers at the
start of the comment,

E.g.::

    TODO 1
    TODO:az09
    RFC 2295
    PEP 257
    FIXME-x_y_z
    XXX:1.2 1.3.1-5


.. class:: sf-mf sf-code mf-sh-cmd

::

    radical.py radical.py
