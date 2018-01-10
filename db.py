#!/usr/bin/env python
""":Created: 2017-04-08
"""
from __future__ import print_function
__description__ = ''
__version__ = '0.0.4-dev' #script-mpe
__db__ = '~/.script.db'
__usage__ = """
Anydbm index client.

Usage:
  db.py [options] insert <key> [<label>]
  db.py [options] drop <key>
  db.py [options] find <glob>
  db.py [options] get <key>
  db.py [options] set <keys>...
  db.py [options] list
  db.py [options] [dump]

Options:
    -q, --quiet   Quiet operations
    -s, --strict  Strict operations
    -k, --key     Match (all) keys instead of tag labels.
    --db DBREF    Database path [default: %s]
    --no-db       Set for some commands..
    --new         Truncate DB
    -h --help     Show this usage description.
    --version     Show version (%s).

""" % ( __db__, __version__ )
import os
import sys
import anydbm
# XXX: See also ``import shelve``

from script_mpe import libcmd_docopt


def get_any_session(opts):
    "Get r/w session to existing or new DB"
    flag = opts.flags.new and 'n' or 'c'
    dbref = os.path.expanduser(opts.flags.db)
    return anydbm.open(dbref, flag)



def H_list(db, opts):
    """
    TODO: re-instate some anydbm tooling when needed. See
    git:b7fc8a7f:tags.py for tag handlers.
    """

def H_dump(db, opts):
    """
    Dump db key, values
    """
    for k in db.keys():
        print(k, db[k])


### Transform H_ function names to nested dict

handlers = libcmd_docopt.get_cmd_handlers_2(globals(), 'H_')


### Main

def main(func, opts):

    db = get_any_session(opts)
    if not opts.flags.no_db:
        assert db, "Missing or empty DB: %s " % opts.flags.db

    return handlers[func](db, opts)


def get_version():
    return 'db.mpe/%s' % __version__

if __name__ == '__main__':
    opts = libcmd_docopt.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit( main( opts.cmds[0], opts ) )
    opts = libcmd_docopt.get_opts(__doc__)
