#!/usr/bin/env python
"""
Use of the target framework.

ToDo:
    - volume, radical, finfo need a rewrite to use the new cmdline.

Work in progress:
    - lnd:tag - Interactive .. can txs: be interactive?

Issues:
    - Rewrite taxus INode to be polymorphic: Dir, File, Dev..

"""

# XXX: development tooling:
try:
    import coverage
    coverage.process_startup()
except ImportError as e:
    pass

# XXX: libcmdng/cmdline2 setup, recover commands. See test/libcmdng-spec.bats
from script_mpe.libhtd import *
#import lib
from script_mpe.libname import Namespace, Name
from script_mpe.libcmdng import Target, TargetResolver, Options
#import cmdline
#import txs
#import lind
#import rsr
#import volume
#import htdocs
#from radical import Radical
#from finfo import FileInfoApp


NS = Namespace.register(
        prefix='cmd',
        uriref='http://project.wtwta.org/script/#/main'
    )

Options.register(NS)

@Target.register(NS, 'options')
def cmd_options(prog=None, opts=None):
    pass


if __name__ == '__main__':
    TargetResolver().main(['cmd:options'])
    #TargetResolver().main([])
