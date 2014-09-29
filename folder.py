#!/usr/bin/env python
""":created: 2014-09-28

TODO: keep open (active) vs. closed (inactive) indictors
    for ... nodes? groups? 
TODO: group other nodes. See GroupNode 1--* Node
TODO: find prelimanary way to represent nodes from other stores
"""
__description__ = "folder - "
__version__ = '0.0.0'
__db__ = '~/.folder.sqlite'
__usage__ = """
Usage:
  folder.py [options] [info|list]

Options:
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]

Other flags:
    -h --help     Show this usage description. 
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).
""" % ( __db__, __version__ )

from datetime import datetime
import os
import re

import log
import util
from taxus.init import SqlBase, get_session
from taxus import \
    Node, Name, Tag, Folder


metadata = SqlBase.metadata


# used by db_sa
models = [ Name, Tag, Folder ]

def print_Folder(folder):
    log.std(
"{blue}%s{bblack}. {bwhite}%s {bblack}[ about:{magenta}%s {bblack}] %s %s %s{default}" % (
                folder.folder_id,
                folder.name,
                folder.about_id,

                str(folder.date_added).replace(' ', 'T'),
                str(folder.last_updated).replace(' ', 'T'),
                str(folder.date_deleted).replace(' ', 'T')
            )
        )


### Commands

def cmd_info(settings):
    for l, v in (
            ( 'DBRef', settings.dbref ),
            ( "Tables in schema", ", ".join(metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

def cmd_list(settings):
    sa = Folder.get_session('default', settings.dbref)
    for t in Folder.all():
        print_Folder(t)

def cmd_new(NAME, REF, settings):
    sa = Folder.get_session('default', settings.dbref)
    folder = Folder.byName(NAME)
    if folder:
        log.std("Found existing folder %s, created %s", folder.name,
                folder.date_added)
    else:
        folder = Folder(name=NAME)
        folder.init_defaults()
        sa.add(folder)
        sa.commit()
        log.std("Added new folder %s", folder.name)
    print_Folder(folder)


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags

    # FIXME: share default dbref uri and path, also with other modules
    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    opts.default = 'info'

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'folder.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))



