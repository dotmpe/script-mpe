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

def gitsize(path, parentdir):
	if parentdir:
		cmd = 'find %s -iname .git | while read f; do du --exclude .git -bs $(dirname $f); done' % path
	else:
		cmd = 'find %s -maxdepth 3 -iname .git -exec du -bs {} + ' % path
	stdin, stdout, stderr = os.popen3(cmd)
	totalgitsize = 0
	for line in stdout.readlines():
		size, path = line.strip().split('\t')
		yield size, path

def total_gitsize(path, parentdir=False):
	totalgitsize = 0
	for size, path in gitsize(path, parentdir):
		totalgitsize += int(size)
	return totalgitsize

if argv:
	if argv[0] == 'autoconf':
		print 'yes'

	elif argv[0] == 'config':

		print 'graph_title Project %r metrics at %s' % (measure, host)
		print 'graph_category projects'

		if measure == 'count':
			print 'graph_vlabel GIT projects (nr)'
			print 'project_count.label GIT project count at %s' % host
			print 'project_count.type GAUGE'
			print 'project_src_count.label GIT repository count at %s' % host
			print 'project_src_count.type GAUGE'
			print 'graph_args --base 1000'

		elif measure == 'size':
			print 'graph_vlabel Project volumes (bytes)'
			print 'graph_args --lower-limit 0 --base 1024'
			print 'project_size_workdir.label GIT working trees at %s' % host
			print 'project_size_workdir.type GAUGE'
			print 'project_size_gitwork.label GIT working repos at %s' % host
			print 'project_size_gitwork.type GAUGE'
			print 'project_size_gitbare.label GIT source repos at %s' % host
			print 'project_size_gitbare.type GAUGE'

		elif measure == 'size_detail':
			print 'graph_vlabel Project volume details (bytes)'
			print 'graph_args --lower-limit 0 --base 1024'
			for size, path in gitsize('/srv/project-mpe/', True):
				path = os.path.basename(path).replace('.', '-')
				print 'project_size_gitwork_%s.type GAUGE' % path
				print 'project_size_gitwork_%s.draw AREASTACK' % path
				print 'project_size_gitwork_%s.label %s' % ( path, path )

else:
	
	if measure == 'count':
		stdin, stdout, stderr = os.popen3('find /srv/project-mpe/ -iname "*.git" | wc -l')
		print 'project_count.value', stdout.read().strip()
		stdin, stdout, stderr = os.popen3('find /src/*/ -iname .git -maxdepth 2 | wc -l')
		print 'project_src_count.value', stdout.read().strip()

	elif measure == 'size':
		totalgitsize = total_gitsize('/srv/project-mpe/', True)
		print 'project_size_workdir.value', totalgitsize
		totalgitsize = total_gitsize('/srv/project-mpe/')
		print 'project_size_gitwork.value', totalgitsize
		totalgitsize = total_gitsize('/src/')
		print 'project_size_gitbare.value', totalgitsize

	elif measure == 'size_detail':
		for size, path in gitsize('/srv/project-mpe/', True):
			path = os.path.basename(path).replace('.', '-')
			print 'project_size_gitwork_%s.value' % path,
			print size

