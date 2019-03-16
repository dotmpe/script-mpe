TODO: context - Tag-name hierarchy, homedoc and status

- Track context "records":

  - ctime-/utime/date
  - prefix:super-tag/sub-tag spec
  - super/sub-contexts

Design
------
There are two dimensions for hierarchy, one bidirectional in the tag namespace
based on path-element and namespace separators, and one bottom-up by tagging
each line with super "class" contexts. See todotxt-format lib, or stattab for
generic record-table setup.

Functions:

1. (List global/local) Context items
2. Check context items
3. New context item

TODO:
  - htd context update
  - htd context start
  - htd context close
  - htd context destroy

* TODO: contexts/ctx-<tag>.lib.sh impl.
* TODO: ~/bin/.doc/htd-ctx.list

Specs
-----
* context.lib
* htd-context.lib

1. ``$ htd context list``
2. ``$ htd context check``
3. ``$ htd context new``

TODO:
  - htd context tree

    txt.py txtstat-tree ...

- htd wf ctx sub (htd.lib.sh)

  - htd current context
  - ctx <primctx> init
  - htd ctx <primctx> <flow> ARGS...

- (doc.lib.sh)

  - args to title
  - doc title id
