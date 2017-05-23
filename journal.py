#!/usr/bin/env python
""":created: 2017-05-08
"""
__description__ = "journal - "
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Usage:
    journal.py [options] [ LIST ]
    journal.py -h|--help
    journal.py --version

Options:
    --verbose     ..
    --quiet       ..
    -h --help     Show this usage description.
    --version     Show version (%s).

""" % ( __version__ )

import os

import script_util
import res.jrnl



def cmd_journal_rw(LIST, opts, settings):
    assert os.path.exists(LIST), LIST
    entries = res.jrnl.JournalTxtManifestParser()
    list(entries.load_file(LIST))
    for k in entries:
        print k,
        print entries[k]



### Transform cmd_ function names to nested dict

commands = script_util.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = script_util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = 'journal-rw'
    return script_util.run_commands(commands, settings, opts)

def get_version():
    return 'journal.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    opts = script_util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))

