.. include:: .default.rst

Htdocs
===============================================================================
Prototype commands for processing local site content/structure
_______________________________________________________________________________


Design
------
- Shell. Bourne Shell, prefer compatibility [#]_.
- Python. Node.JS. Perl and other regulars (make, grep, sed, ed, awk, but also moreutils etc.). Ruby. XSLT.
- Data abstraction layer for shell glue in Statusdir_.
- Local metadata through Package_. Working with project packages through Projectdoc YAML/JSON and Projectdir: Pd_.

.. [#] tested, devved on Debian and Darwin/BSD hosts.

Summaries
_________
These are feature summaries.

htd vt
  See htd-rst-doc-create-update modes for tags.

htd process [ LIST [ TAG.. [ --add | --any | --save ] ]
  Process items from list with tag, using any backend found
  for tag.
  Optionally include all items to the tag processor, or add
  items missing the tag before passing to the processor.
  Without tags given, the default is to look up the tags
  for the given LIST.

htd tasks-hub
  Helpers for processing TODO.txt-type lists in ``./to`` dir.

Plan
----
TODO: SCRIPT-MPE-1 advanced rules: provide for scheduled and context triggered
rules engine. Ie. a simple cron-esque runner, but also automatic domain network
switch, etc.

Until above requirement is met, htd is a bit of the largest bag in +script-mpe.
And this spec is not actual, but inline htd.sh documentation and structure is
preferred. Should turn lots of comments into proper tasks and more but until
that starts, focus here is on getting SCRIPT-MPE-1 into dev.

But related script/backend work in progress related to below is in Tasks_,
mabye Topics_.

Dev
-------
- Project tooling <project.rst>

Issues
-------

Spec
----
Workflows

htd
  - package
  - run
  - doc
  - find
  - edit
