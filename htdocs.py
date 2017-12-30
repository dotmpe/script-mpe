#!/usr/bin/env python
"""
:Created: 2013-06-30

TODO: construct TopicTree from Definition Lists in restructured text.
See also filetree.

FIXME: move something like a definition parser to elsewhere? something simple
    and lightweight perhaps to fit rsrlib.res,
"""
from __future__ import print_function
__db__ = '~/.htdocs.sqlite'
import os

from dotmpe.du import comp, frontend

#from script_mpe import res
import log
import confparse
import res.fs
from libname import Namespace
import libcmd
from libcmdng import Targets, Arguments, Keywords, Options,\
    Target
import traceback

# XXX: not much CLI (TODO: update, status) but using taxus ORM schema
from taxus import v0, get_session
models = v0.models
SqlBase = v0.SqlBase


class Htdocs(libcmd.SimpleCommand):

    PROG_NAME = os.path.splitext(os.path.basename(__file__))[0]
    VERSION = "0.1"
    USAGE = """Usage: %prog [options] paths """

    DEFAULT = [ 'status' ]
    #DEFAULT_CONFIG_KEY = 'htdocs'

    def __init__(self):
        super(Htdocs, self).__init__()

    @classmethod
    def get_optspec(klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
        return (
                (('--status',), libcmd.cmddict()),
                (('--update',), libcmd.cmddict()),
            )

    def status(self, sa=None, *paths):
        pass

    def update(self, sa=None, *args):
        pass


if __name__ == '__main__':
    Htdocs.main()
