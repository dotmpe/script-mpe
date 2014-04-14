#!/usr/bin/env python
"""
"""

import os

import libcmd
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


if __name__ == '__main__':
    VC.main()


