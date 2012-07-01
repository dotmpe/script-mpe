"""
Read metadata from metafiles.

- Persist composite objects
- Metalink4 <-> HTTPResponseHeaders

- Content-*

"""
import os


import iface
#import lib
import confparse
#from taxus import get_session
import log

import lib
import util
from persistence import PersistedMetaObject
from fs import File, Dir
from mime import MIMEHeader
from metafile import Metafile
from volume import Workspace, Volume
from vc import Repo


#class HTTPHeader(MIMEHeader):
#    pass
#
#class HTTPResponse(HTTPHeader):
#    pass


