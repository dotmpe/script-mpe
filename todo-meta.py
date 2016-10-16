#!/usr/bin/env python
""":created: 2015-11-30
"""
__description__ = "todo-meta - todo document proc"
__version__ = '0.0.2-dev' # script-mpe
__usage__ = """
Usage:
  todo-meta.py [options] info
  todo-meta.py import <file>
  todo-meta.py help
  todo-meta.py -h|--help
  todo-meta.py --version


Other flags:
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __version__ )
from pprint import pformat

import util



### Commands

def cmd_info(opts):
    """
    """
    print pformat(opts.todict())


def cmd_import(opts):
    """
    Import from file/stdin. This uses grep output with embedded tags, and
    takes the entire line as description. No further parsing, beyond
    scanning for the tag ID. Syntax (e.g. for unix comment line)::

        <file>:<linenr>: # Comment .. TODO:<id>: blah blah ... comment

    :XXX: work in progress.
    :TODO: why not use some context: <project>#TODO etc.
        Right now, it is not clear what the matched lines are for.

    ::
        <basedir>;<project>#TODO:<id>;<file>:<linenr>: # Comment .. TODO:<id>: blah blah ... comment


    """
    if opts.args.file == '-':
        import sys
        data = sys.stdin.readlines()
    else:
        data = open(opts.args.file).readlines()

    for line in data:
        p = line.index(';')
        basedir, line = line[:p], line[p+1:]
        p = line.index(';')
        local_ctx_id, line = line[:p], line[p+1:]
        p = line.index(':')
        file, line = line[:p], line[p+1:]
        p = line.index(':')
        linenr, line = line[:p], line[p+1:]
        print pformat(dict(
           basedir=basedir,
           local_ctx_id=local_ctx_id,
           file=file,
           linenr=linenr,
           line=line
        ))



### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    values = opts.args

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'todo-meta.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))

