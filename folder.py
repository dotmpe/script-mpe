#!/usr/bin/env python
""":created: 2014-09-28
:updated: 2014-10-12

TODO: keep open (active) vs. closed (inactive) indicators for groups
TODO: group other nodes. See GroupNode 1--* Node from taxus.Core.
TODO: find prelimanary way to represent nodes from other stores
TODO: print path relative to current dir

"""
__description__ = "folder - "
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.folder.sqlite'
__usage__ = """
Usage:
  folder.py [options] [info|list]
  folder.py [options] new NAME [REF]
  folder.py [options] group ID SUB...
  folder.py [options] ungroup SUB...

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
import libcmd_docopt
import taxus
from taxus.init import SqlBase, get_session
from taxus import \
    Node, Name, Tag, Folder


metadata = SqlBase.metadata


# used by db_sa
models = [ Name, Tag, Folder ]

def print_Folder(folder):
    log.std(
"{blue}%s{bblack}. {bwhite}%s {bblack}[ type:{magenta}%s {bblack} parent:{cyan}%s ] %s %s %s{default}" % (
                folder.folder_id,
                folder.name,
                folder.ntype,
                folder.root,

                str(folder.date_added).replace(' ', 'T'),
                str(folder.date_updated).replace(' ', 'T'),
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
    # if pwd in Projectdir, Volumedir or Homedir
    # display relative path for output nodes

def cmd_list(settings):
    sa = Folder.get_session('default', settings.dbref)
    for t in Folder.all():
        print_Folder(t)

def cmd_new(NAME, REF, settings):
    sa = Folder.start_session('folder', settings.dbref)
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


# GroupNode operations

def cmd_group(ID, SUB, settings):

    """
        folder group ID SUB...
    """

    taxus.ORMMixin.init('folder', settings.dbref)
    sa = Folder.start_session('folder', settings.dbref)
    root = Folder.fetch_instance(ID, 'folder')
    for subid in SUB:
        sub = Folder.fetch_instance(subid, 'folder')
        sub.partOf_id = ID
        # XXX abstract using some kind of master store iface
        sa.add(node)
    sa.commit()

def cmd_ungroup(SUB, settings):
    """
        folder ungroup ID
    """
    sa = Folder.start_session('folder', settings.dbref)
    for subid in SUB:
        sub = Folder.fetch_instance(subid, 'folder')
        node.partOf_id = None
        sa.add(node)
    sa.commit()


# Folder operations

def cmd_rename(SRC, DEST):
    """
        folder rename SRC DST

    Accepts (greedy) globs and relative paths.
    """
    store = Node.start_master_session()
    src = Node.lookup(SRC)
    for d in DEST:
        d = Node.lookup(d)



### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = 'info'
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'folder.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = libcmd_docopt.get_opts(__description__ + '\n' + __usage__, version=get_version())
    opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
