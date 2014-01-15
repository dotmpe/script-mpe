#!/usr/bin/env python
"""cmdline - 
"""
import os
import sys
import re

import zope.interface

import confparse
import log
import libcmd



class Cmd(libcmd.StackedCommand):

    NAME = 'cmd'

    DEFAULT = ['stat']
    DEPENDS = {
            'stat': [],
        }

    OPTS_INHERIT = '-v', '-q'

    @classmethod
    def get_optspec(Klass, inheritor):
        p = inheritor.get_prefixer(Klass)
        return ()

    def stat(self, prog, settings):
        print prog, settings


if __name__ == '__main__':
    Cmd.main()

