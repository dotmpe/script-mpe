#!/usr/bin/env python
from __future__ import print_function
"""
:created: 2015-06-29

"""

__description__ = 'host -'
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.taxus-code.sqlite'
__rc__ = '~/.domain.rc'
__usage__ = """

Usage:
  host.py [options] ( find <ref>...
                       | info [ <ref>... ]
                       | init [ -p... ]
                       | list
                       | new -p...
                       | update -p... <ref> )
  host.py [options] test init

Options:
    -c RC --config=RC
                  Use config file to load settings [default: %s]
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s].

Other flags:
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __rc__, __db__, __version__ )
__doc__ += __usage__

import os
from datetime import datetime

import log
import libcmd_docopt
from libcmd_docopt import cmd_help
from taxus import Node, Host, ScriptMixin
from domain2 import init_host



def cmd_init(settings):
    sa = Host.get_session('default', settings.dbref)
    host_dict = init_host(settings)
    name = host_dict['name']
    record = Host.fetch(filters=(Host.name == name,), sa=sa, exists=False)
    if not record:
        host = Host(name=name, date_added=datetime.now(),
                date_updated=datetime.now())
        sa.add(host)
        sa.commit()
        log.std('{bwhite}Added host %s record{default}', name)
    else:
        host = record
    print('host at', host_dict.path(), ':', host)

def cmd_list(settings):
    sa = Host.get_session('default', settings.dbref)
    for h in sa.query(Host).all():
        print(h)

def cmd_test_init(settings):
    sa = Host.get_session('default', settings.dbref)
    host_dict = init_host(settings)
    name = host_dict['name']
    print(Host.fetch(filters=(Host.name == name,), sa=sa, exists=False))
    #print Host.init(sa=sa)


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help

### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    #settings = opts.flags
    opts.flags.configPath = os.path.expanduser(opts.flags.config)
    settings = libcmd_docopt.init_config(opts.flags.configPath, dict(
            nodes = {}, interfaces = {}, domain = {}
        ), opts.flags)
    opts.default = 'info'
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'taxus-host-py.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    opts = libcmd_docopt.get_opts(__doc__, version=get_version())
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
