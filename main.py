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
#from libcmd import Cmd
import cmdline
#from taxus import Taxus
import txs
import lind
#from rsr import Rsr
from resourcer import Resourcer
#from volume import Volume
#from radical import Radical
#from finfo import FileInfoApp


#namespace = 'script-mpe', 'http://name.wtwta.nl/#/rsr'

if __name__ == '__main__':

    cmdline.TargetResolver().main(['cmd:options'])

