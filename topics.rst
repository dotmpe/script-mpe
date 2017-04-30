.. include:: .default.rst

Topics
========
:created: 2017-04-08

Design
-------
- Python, SQLAlchemy and sqlite for designing relational structure.
- Redis for (semi-)volatile key/value storage. Should persist/sync between
  on-disk items for some flows. See also Statusdir_.

SCRIPT-MPE: like tasks process items as being topics, retrieved from different
contexts, but indexed and cross-referenced


Plan
-----
persist, backup list

Dev
-----
topic
  Gives taxus model/db_sa.py access with SQLite DB.

  One root with three sub topics::

    topic new "Root 2017"
    topic new "Web" 1
    topic new "Personal" 1
    topic new "Notes" 1

  [2017-04-17] trying to build an extensible parser, for outlines again::

    topic.py read-list test.txt
    topic.py read-list --apply-context Outline hier.txt
    topic.py write-list hier.txt @Outline


Issues
------


Spec
-----
.. If possible, link to test results

----

.. See .default for document structures
