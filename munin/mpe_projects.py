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



projects = [
			'htcache'
		]
branches = {
		'htcache': (
				'dev',
				'master',
				'dev_domaindb',
				'dev_dhtmlui',
				'dev_proxyreq',
				'dev_cachemaint',
				'dev_relstore',
			)
		}

args = list(sys.argv)
host = socket.gethostname()
script = args.pop(0)
measure = 'loc'
project = None
if '_' in script:
	parts = script.split('_')[1]
	if len(parts) == 1:
		measure = parts
	elif len(parts) == 2:
		measure, project = parts

if args:
	if args[0] == 'autoconf':
		print 'yes'
	elif args[0] == 'config':

		print 'graph_category projects'
		print 'graph_args --base 1000'
		print 'graph_title %s: Project %r metrics' % (host, measure)

		if measure == 'count':
			print 'graph_vlabel (nr)'
			for p in projects:
				print '%s_count.label %s' % p
				print '%s_count.type GAUGE' % p

		elif measure == 'loc':
			print 'graph_vlabel (loc)'
			for p in projects:
				print '%s_loc.label %s' % p
				print '%s_loc.type GAUGE' % p

		elif measure == 'loc-detail':
			assert project
			print 'graph_vlabel (loc)'
			print '%s_conf_loc.label %s' % project
			print '%s_conf_loc.type GAUGE' % project
			print '%s_tpl_loc.label %s' % project
			print '%s_tpl_loc.type GAUGE' % project
			print '%s_src_loc.label %s' % project
			print '%s_src_loc.type GAUGE' % project

		elif measure == 'tests':
			assert project
			print 'graph_vlabel (tests)'
			for b in branches[project]:
				print '%s_passed_tests.label %s passed' % project
				print '%s_passed_tests.type GAUGE' % project
				print '%s_passed_tests.draw AREASTACK'
				print '%s_failure_tests.label %s failures' % project
				print '%s_failure_tests.type GAUGE' % project
				print '%s_failure_tests.draw AREASTACK' % project
				print '%s_error_tests.label %s errors' % project
				print '%s_error_tests.type GAUGE' % project
				print '%s_error_tests.draw AREASTACK' % project

		elif measure == 'git-branches':
			pass

else:
	if measure == 'count':
		update()
		for p in projects:
			pass

	elif measure == 'loc':
		for p in projects:
			data = open(os.path.expanduser('~/project/%s/test-results.tab')
			print data

	elif measure == 'loc-detail':
		assert project

	elif measure == 'tests':
		assert project


