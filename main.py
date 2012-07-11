#!/usr/bin/env python
"""
Use of the target framework.

ToDo:
    - Rewrite so target execution is stacked. May want to review
      handler/execution list sequence.
    - volume, radical, finfo need a rewrite to use the new cmdline.

Work in progress:
    - lnd:tag - Interactive .. can txs: be interactive?

Issues:
    - Rewrite taxus INode to be polymorphic: Dir, File, Dev..

"""
from target import Name, Target, AbstractTargetResolver
#from libcmd import Cmd
from cmdline import Command

#from taxus import Taxus
from txs import Txs
from lind import  Lind
#from rsr import Rsr
from resourcer import Resourcer
#from volume import Volume
#from radical import Radical
#from finfo import FileInfoApp


class Main(Command, AbstractTargetResolver):

    handlers = [
            'cmd:options'
        ]

    @classmethod
    def get_opts(self):
        return ()

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

