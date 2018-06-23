"""
res - Read metadata from metafiles.

Types to represent anything. The objective is using this as a toolkit, to
integrate into programs that work on metadata and/or (media) files. The hope is
to separate it according to focus into different projects or components, someday.

Module dir:
  - res.lst - misc. types of simple lists from plain-text: dates, numbers, URL's
  - res.todo - TODO.txt format on steriods
  - res.task - data sync and events for res.txt items
  - res.txt - this file, interfaces and abstract types
  - res.bm - formats for bookmark exports, JSON and HTML
  - res.fs - list and walk filesytem, with include/exclude name matching
  - res.ws - work with metadirs as context
  - res.vc - find version-control repositories and list contents

Metafile dotdirs and files
--------------------------
TODO: move some higher level res.metafile docs here.

Plain-text items and lists
--------------------------
res.txt is a customizable factory/generator style parser that takes in a file at
list-parser and lets a line-parser extract the same fields each line using
handlers provided a number of type mixins.

It includes varying abstract strategies for parser setup and result handling.
A simple list-item type is provided, which represents an item from a plain-test
list as a complex structure

 - text
 - attributes

TODO: refactor so that result isn't a bunch of AbstractTxtLineParser instances.
XXX: line fields/types and list record keying and sorting.

Based on this pattern, some subtypes are given elsewhere in `res` for
specific formats: TODO.txt

----

TODO:
  - res.disk
  - res.metafile - metadir and metafile types for dotfiles and dotdirs as markers
    and default file locations

TODO:
- Persist composite objects:
- Metalink reader/adapter. Metalink4 <-> HTTPResponseHeaders
- Content-* properties
- Combine with or harves cllct, and existing rsr and taxus projects.
"""

from fs import File, Dir
from mimemsg import MIMEHeader
from metafile import Metafile, Metadir, Meta, SHA1Sum
from jrnl import Journal
from vc import Repo
from js import AbstractYamlDocs
from ws import Workspace, Homedir, Workdir, Volumedir
import task
from task import Task, TaskListParser, RedisSEIStore
import todo
from todo import TodoTxtParser
from disk import Diskdoc
from pfx import Prefixes

import iface
