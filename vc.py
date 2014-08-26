#!/usr/bin/env python
"""
:updated: 2014-08-26

Usage:
  vc.py [options] db (init|reset|stats)
  vc.py [options] vc (find|info)
  vc.py -h|--help
  vc.py --version

Options:
    -v            Increase verbosity.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: ~/.vc.sqlite].
    -p --props=NAME=VALUE

Other flags:
    -h --help     Show this screen.
    --version     Show version.

"""

import os
import re

from docopt import docopt

import libcmd
import util
import rsr
import log


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
        print 'context=',context
        print 'sa=',sa
        # TODO: should be some workspace
        log.info('vc:repos done')



###



def cmd_db_init(settings):
    """
    Initialize if the database file doest not exists,
    and update schema.
    """
    model.get_session(settings.dbref)
    # XXX: update schema..
    metadata.create_all()

def cmd_db_stats(settings):
    """
    Print table record stats.
    """
    sa = get_session(settings.dbref)
    for m in [ Node, Topic ]:
        print m.__name__, sa.query(m).count()

def cmd_project_find(settings):
    sa = get_session(settings.dbref)
    #project = Project.find()

def cmd_project_info():
    print 'project-info'


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    if opts['--version']:
        print 'bookmark/%s' % __version__
        return

    settings = util.get_opt(opts)

    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    return util.run_commands(commands, settings, opts)


if __name__ == '__main__':
    #VC.main()

    import sys
    opts = docopt(__doc__)
    sys.exit(main(opts))




