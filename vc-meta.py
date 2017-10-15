#!/usr/bin/env python
"""
:updated: 2014-08-26

Usage:
  vc.py [options] (find|info)
  vc.py help|-h|--help
  vc.py --version

Options:
    -v            Increase verbosity.
    -c RC --config=RC
                  Use config file to load settings [default: ~/.vc.rc]
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: ~/.vc.sqlite].
    -p --props=NAME=VALUE

Other flags:
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version.

"""
__version__ = '0.0.4-dev' # script-mpe

from __future__ import print_function
import os
import re

from docopt import docopt

from . import libcmd
from . import libcmd_docopt
from . import rsr
from . import log


class VC(rsr.Rsr):

    """
    VC manages a version controlled checkout,
    with targets based on vc:tree.

    To manage multiple checkouts and repositories,
    vc:repo reports on the dirs within current workspace.
    """

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    assert NAME == 'vc'
    DEFAULT_CONFIG_KEY = NAME
    DEPENDS = {
        'vc_repos': [ 'rsr_session' ],
        'vc_repo': [ 'rsr_session' ],
        'vc_status': [ 'vc_repo' ],
    }

    DEFAULT_DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
    DEFAULT_DB = "sqlite:///%s" % DEFAULT_DB_PATH
    DEFAULT_DB_SESSION = 'default'

    DEFAULT = [ 'vc_status' ]

    @classmethod
    def get_optspec(Klass, inheritor):
        """
        Return tuples with optparse command-line argument specification.
        """
        p = inheritor.get_prefixer(Klass)
        return (
                p(('--repo',), libcmd.cmddict(inheritor.NAME, append=True)),
                p(('--repos',), libcmd.cmddict(inheritor.NAME, append=True)),
            )

    def vc_repo(self, prog=None, sa=None, context=None):
        """
        TODO: Yield VC manager for current checkout dir
        """
        # TODO: should be VC checkout dir
        log.info('vc:repos done')

    def vc_status(self, prog=None, sa=None, context=None):
        """
        TODO: Report status bits, dirty lists and summaries
        """
        log.info('vc:status done')

    def vc_repos(self, prog=None, sa=None, context=None):
        """
        TODO: Yield all repositories in workspace.
        """
        print('context=',context)
        print('sa=',sa)
        # TODO: should be some workspace
        log.info('vc:repos done')


###

models = [ Node, Topic ]

def cmd_find(settings):
    sa = get_session(settings.dbref)
    #= Project.find()

def cmd_info():
    print('info')


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    opts.flags.configPath = os.path.expanduser(opts.flags.config)
    settings = libcmd_docopt.init_config(opts.flags.configPath, dict(
            nodes = {}, interfaces = {}, domain = {}
        ), opts.flags)

    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'vc.mpe/%s' % __version__

if __name__ == '__main__':
    #VC.main()
    import sys
    opts = libcmd_docopt.get_opts(__doc__, version=get_version())
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
