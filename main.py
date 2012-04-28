#!/usr/bin/env python

from target import Name, Target, AbstractTargetResolver
from cmdline import Command
from resources import Resourcer

from libcmd import Cmd
from taxus import Taxus
from rsr import Rsr
from volume import Volume
from radical import Radical
from finfo import FileInfoApp


class Main(AbstractTargetResolver, Resourcer):
    pass

    #namespace = 'script-mpe', 'http://name.wtwta.nl/#/rsr'

    #handlers = [
    #        'cmd:options',
    #    ]
    #@classmethod
    #def get_opts(klass):
    #    return ()

    #@staticmethod
    #def get_options():
    #    return Cmd.get_opts() \
    #            + Taxus.get_opts() \
    #            + Rsr.get_opts()


if __name__ == '__main__':
    Main().main()

