#!/usr/bin/env python
"""
:created: 2017-08-13

"""
__description__ = "uris - "
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.bookmarks.sqlite'
__usage__ = """
Usage:
  uris.py [options] list [NAME]
  uris.py -h|--help
  uris.py --version

Options:
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    -s SESSION --session-name SESSION
                  should be bookmarks [default: default].
    --output-format FMT
                  json, repr [default: rst]
    --no-commit   .
    --commit      [default: true].
    -v            Increase verbosity.
    --verbose     Default.
    -q, --quiet   Turn off verbosity.
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __db__, __version__, )
from datetime import datetime, timedelta
import os
import re
import hashlib
import urllib
from urlparse import urlparse

import couchdb
#import zope.interface
#import zope.component
from pydelicious import dlcs_parse_xml
from sqlalchemy import or_
import BeautifulSoup

import log
import confparse
import libcmd_docopt
import libcmd
import rsr
import taxus.iface
import res.iface
import res.js
import res.bm
from res import Volumedir
from res.util import ISO_8601_DATETIME
from taxus import init as model
from taxus.init import SqlBase, get_session
from taxus.core import ID, Node, Name, Tag
from taxus.net import Locator, Domain
from taxus.model import Bookmark


models = [ Locator, Tag, Domain, Bookmark ]

# were all SQL schema is kept. bound to engine on get_session
SqlBase = model.SqlBase



def cmd_list(NAME, settings):
    """List locators"""

    sa = Locator.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Locator.search(name=NAME)
    else:
        rs = Locator.all()
    if not rs:
        log.std("Nothing")

    of = settings.output_format
    if of == 'json':
        def out( d ):
            for k in d:
                if isinstance(d[k], datetime):
                    d[k] = d[k].isoformat()
            return res.js.dumps(d)
    else:
        tpl = taxus.out.get_template("locator.%s" % of)
        out = tpl.render

    for l in rs:
        print out( l.to_dict() )


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute using docopt-mpe options.
    """

    settings = opts.flags
    opts.flags.commit = not opts.flags.no_commit
    opts.flags.verbose = not opts.flags.quiet
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'bookmarks.mpe/%s' % __version__

if __name__ == '__main__':
    #bookmarks.main()
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    db = os.getenv( 'BOOKMARKS_DB', __db__ )
    # TODO : vdir = Volumedir.find()
    if db is not __db__:
        __usage__ = __usage__.replace(__db__, db)
    opts = libcmd_docopt.get_opts(__doc__ + __usage__, version=get_version())
    opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
