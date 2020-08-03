#!/usr/bin/env python
# Created: 2015-12-27
# Updated: 2020-07-30
from __future__ import print_function
__description__ = 'x-gtasks Google Tasks API Python CLI'
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Experimental Google Tasks

Usage:
    gtasks [options] [list]
    gtasks [options] login [--valid]
    gtasks help | --help
    gtasks --version

Options:
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -S, --secret CLIENT_ID_FILE
                JSON formatted client secret (credentials).
  -T, --token CLIENT_TOKEN_FILE
                Pickled client token (validated credentials).
  -n, --pagesize NUM
                Set result-length (1-100) [Default: 20]
  --print-memory
                Print memory usage just before program ends.

"""
import os
from pprint import pprint, pformat

import datetime
from datetime import timedelta
from datetime import datetime

from script_mpe import libcmd_docopt, libgapi_mpe
import confparse


CLIENT_ID_FILE = os.path.expanduser('~/.local/etc/token.d/google/x-script-mpe/credentials.json')
CLIENT_TOKEN_FILE = os.path.expanduser('~/.local/etc/token.d/google/x-script-mpe/credentials-gtasks.pickle')

SCOPES = ['https://www.googleapis.com/auth/tasks']


def gtasks_defaults(opts, init={}):
    libcmd_docopt.defaults(opts)

    if not opts.cmds:
        opts.cmds = ['list']

    if not opts.flags.secret:
        if 'GCAL_JSON_CLIENT_ID_FILE' in os.environ:
            opts.flags.secret = os.environ['GCAL_JSON_CLIENT_ID_FILE']
        else:
            opts.flags.secret = CLIENT_ID_FILE

    if not opts.flags.token:
        if 'GCAL_TOKEN_FILE' in os.environ:
            opts.flags.token = os.environ['GCAL_TOKEN_FILE']
        else:
            opts.flags.token = CLIENT_TOKEN_FILE

    return init


## Sub-cmd handlers

def cmd_list(g, opts):
    service = g.services.tasks
    r = service.tasklists().list(maxResults=g.pagesize).execute()
    for i in r['items']:
        print("{}\t#{}".format( i['title'], i['id']))
        # print(pformat(service.tasks().list(tasklist=i['id']).execute()))


commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands.update(libcmd_docopt.command_handlers)
commands.update(libgapi_mpe.command_handlers)

def gtasks_main(opts):
    g = opts.flags
    g.credentials = libgapi_mpe.load_secrets(opts.flags.token)
    libgapi_mpe.get_services(g, 'tasks')
    ret = libcmd_docopt.run_commands(commands, g, opts)
    if g.print_memory:
        libcmd_docopt.cmd_memdebug(g)
    return ret

def gtasks_version():
    return 'x-gtasks.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf8')
    opts = libcmd_docopt.get_opts(__description__+'\n'+__usage__,
            version=gtasks_version(), defaults=gtasks_defaults)
    sys.exit( gtasks_main( opts ) )
