#!/usr/bin/python

"""
- total number of project folders
- total number of GIT projects (with or without errors)
- total number of GIT checkouts (clean or dirty)
- total number of GIT branches (locally)
- stack of project lines for all projects 
- stack of checked out branch names for all projects
"""
import os
import sys
import re
import time
import socket
from pprint import pformat


argv = list(sys.argv)
host = socket.gethostname()
script = os.path.basename(argv.pop(0))
argstring = script.replace('mpe_project_','')
measure = 'loc'
if argstring:
	measure = argstring

if argv:
	if argv[0] == 'autoconf':
		print 'yes'

	elif argv[0] == 'config':

		print 'graph_title Project %r metrics' % (measure)
		print 'graph_category projects'
		print 'graph_args --base 1000'

		if measure == 'count':
			print 'graph_vlabel (nr)'
			print 'project_count.label project count at %s' % host
			print 'project_count.type GAUGE'

else:
	
	if measure == 'count':
		stdin, stdout, stderr = os.popen3('find /home/berend/project/ -iname .git | wc -l')
		print 'project_count.value', stdout.read().strip()

