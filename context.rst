Context
=======
TODO: context - Tag-name hierarchy, homedoc and status

- Track context "records":

  - ctime-/utime/date
  - prefix:super-tag/sub-tag spec
  - super/sub-contexts

The basic scheme is a a todo.txt-esque formatted file.
To store tags and describe them as either classes or instances of contexts.
It forms the basis for these design specs.

Design
------
See todotxt-format lib, or stattab for generic record-table setup.

Tags are unique, can only appear as either super- or sub-tag. a context item
can group several tag-ids (no spaces allowed in tag), and also use tags in
(metadata) annotations.

Tags have a namespace binding it to a package- or special directory.

There are are roughly two ways to model hierarchy: using ':' or '/'-separated
path elements in the main Tag-Id, or one at the contexts or other annotations.

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

::

    context_parse "$(NS=DIR context_tag_entry Tag)"


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
