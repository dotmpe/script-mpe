#!/usr/bin/env python
"""
:Created: 2014-02-16

XXX: can I improve htdocs.py, or should that finish first

Model
    ID
        Localpath
            - netpath

    Node
        - name

        RstDoc
            - builder : [ "standalone" ]
        Topic
            ..
        Day
            - gregorian

"""
from __future__ import print_function

__description__ = "journal - "
__version__ = '0.0.4-dev' # script-mpe

import os

from script_mpe import rsr, libcmd
from script_mpe.taxus import core
from script_mpe.res import Journal


class Day(core.Node):
    gregorian = ''

class RstDoc(core.Node):
    build = 'standalone'


class Jrnl(rsr.Rsr):

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    assert NAME == 'jrnl'
    DEFAULT_RC = 'cllct.rc'
    DEPENDS = {
            'jrnl_session': [ 'rsr_session' ],
            'jrnl_info': [ 'jrnl_session' ]
        }
    DEFAULT = [ 'jrnl_info' ]

    @classmethod
    def get_optspec(Klass, inheritor):
        """
        Return tuples with optparse command-line argument specification.
        """
        p = inheritor.get_prefixer(Klass)
        return (
                )

    def jrnl_session(self, prog, opts, sa, volume, workspace):
        print(volume.guid)
        return
        journal = Journal()
        journal = Journal.find(prog.pwd)
        journal.fetch_from_session(sa)
        print(journal)
        yield dict(journal=journal)

    def jrnl_info(self, journal, *args):
        print('Journal info:', self, journal, args)


if __name__ == '__main__':
    import sys
    args = sys.argv[1:]
    if '-h' in args:
        print(__doc__)
        sys.exit(0)
    Jrnl.main()
