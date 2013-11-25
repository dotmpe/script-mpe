#!/usr/bin/python

"""
Also:
	- solar wind data at http://umtof.umd.edu/pm

"""
import re
import sys


args = list(sys.argv)
script = args.pop(0)
if '_' in script:
	measure = script.split('_')[1]
else:
	measure = 'density'

#print '# script: ',script
#print '# measure: ',measure

if args:
	if args[0] == 'autoconf':
		print 'yes'
	elif args[0] == 'config':

		print 'graph_category space'
		print 'graph_args --base 1000'
		print 'graph_title SOHO monitor: %s' % (measure)

		if measure == 'density':
			print 'density.label Density'
			print 'density.type GAUGE'
		elif measure == 'vsw':
			print 'vsw.label Vsw'
			print 'vsw.type GAUGE'
		elif measure == 'vth':
			print 'vth.label Vth'
			print 'vth.type GAUGE'
		elif measure == 'pm':
			print 'pm_max.label PM maximum'
			print 'pm_max.type GAUGE'
			print 'pm_min.label PM minimum'
			print 'pm_min.type GAUGE'

else:
	import urllib2
	import os
	import re
	import time

	tmpf = '/tmp/umtof-umd-edu'
	refresh = 5 * 60

	if not os.path.exists(tmpf) or os.path.getmtime(tmpf) + refresh < time.time():
		f = urllib2.urlopen('http://umtof.umd.edu/pm/pmsw.used')
		content = f.read()
		f.close()
		f = open( tmpf, 'w' )
		f.write(content)
		f.close()
	else:
		content = open( tmpf ).read()

	p = content.index('\n')
	header = content[:p]
	lastrow = content.strip().split('\n').pop()
	line = re.sub('\s+', ' ', lastrow)

	data = {}
	yr, dt, angle, vth, density, vsw, pm_min, pm_max = line.strip().split(' ')
	data['density'] = density
	data['angle'] = angle
	data['vth'] = vth
	data['vsw'] = vsw
	if measure == 'pm':
		print "pm_max.value", pm_max
		print "pm_min.value", pm_min
	if measure in data:
		print "%s.value" % measure, data[measure]



