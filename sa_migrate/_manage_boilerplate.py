#!/usr/bin/env python

if __name__ == '__main__':
	import sys, os
	sys.path.insert(0, 'sa_migrate')
	import custom
	custom.main(os.path.basename(os.path.dirname(__file__)))
