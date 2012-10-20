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
import lib
from libcmd import TargetResolver
import cmdline
import txs
import lind
import rsr
import volume
#from radical import Radical
#from finfo import FileInfoApp


#namespace = 'script-mpe', 'http://name.wtwta.nl/#/rsr'

if __name__ == '__main__':

	TargetResolver().main(['cmd:options'])

