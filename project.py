#!/usr/bin/env python
"""

"""
import os
import libcmd

import rsr
from taxus import Node, Topic
from res import Journal, Project


class Prjct(rsr.Rsr):

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    assert NAME == 'project'
    DEFAULT_RC = 'cllct.rc'
    DEPENDS = { 
            'project_session': [ 'rsr_session' ],
            'project_info': [ 'project_session' ] 
        }
    DEFAULT = [ 'project_info' ]

    @classmethod
    def get_optspec(Klass, inheritor):
        """
        Return tuples with optparse command-line argument specification.
        """
        p = inheritor.get_prefixer(Klass)
        return (
                )

    def project_session(self, prog, opts, sa, volume, workspace):
        project = Project.find()
        yield dict(project=project)

    def project_info(self, journal, *args):
        print 'Project info:', self, journal, args


if __name__ == '__main__':
    Prjct.main()

