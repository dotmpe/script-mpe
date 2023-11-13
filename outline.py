#!/usr/bin/env python
"""
"""
__description__ = "outline - "
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Usage:
  outline.py [options] read-tab <FILE>

Options:

Other flags:
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).
""" % ( __version__, )

from script_mpe.libhtd import *


### Commands

# TODO: insert prefix for tags and comment
# TODO: collapse
def cmd_read_tab(FILE, opts, g):
    """
    """
    lines = open(FILE).readlines()



### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = 'read'
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'outline.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = libcmd_docopt.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))
