"""
res - Read metadata from metafiles.

Classes to represent a file or cluster of files from which specific metadata
may be derived. The objective is using this as a toolkit, to integrate into
programs that work on metadata and/or (media) files.

:XXX: three locations of metadir to bootstrap metadata framework: localdir,
    volumedir, or homedir.

TODO:
- Persist composite objects:
- Metalink reader/adapter. Metalink4 <-> HTTPResponseHeaders
- Content-* properties
"""

#from fs import File, Dir
from mime import MIMEHeader
from metafile import Metafile, Metadir, Meta, SHA1Sum
from jrnl import Journal
from vc import Repo
from ws import Workspace, Homedir, Workdir, Volumedir

import iface

