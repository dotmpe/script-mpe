#!/usr/bin/python

"""
Also:
	- solar wind data at http://umtof.umd.edu/pm

"""
import os
import sys
import re
import time


args = list(sys.argv)
script = args.pop(0)
if '_' in script:
	measure = script.split('_')[1]
else:
	measure = 'sunspotnr'

if args:
	if args[0] == 'autoconf':
		print 'yes'
	elif args[0] == 'config':

		print 'graph_category space'
		print 'graph_args --base 1000'
		print 'graph_title Space weather: %s' % (measure)

		if measure == 'sunspotnr':
			print 'graph_vlabel (nr)'

			print 'sunspotnr.label Sunspot number'
			print 'sunspotnr.type GAUGE'

		elif measure == 'sunradio':
			print 'graph_vlabel (sfu)'

			print 'sunradio.label 10.7 cm flux'
			print 'sunradio.type GAUGE'

		elif measure == 'solarwindspeed':
			print 'graph_vlabel (km/sec)'

			print 'solarwindspeed.label Windspeed'
			print 'solarwindspeed.type GAUGE'

		elif measure == 'solarwinddensity':
			print 'graph_vlabel (protons/cm3)'

			print 'solarwinddensity.label Density'
			print 'solarwinddensity.type GAUGE'

else:
	import urllib2
	from BeautifulSoup import BeautifulSoup

	tmpf = '/tmp/spaceweather-com'
	refresh = 5 * 60

	if not os.path.exists(tmpf) or os.path.getmtime(tmpf) + refresh < time.time():
		f = urllib2.urlopen('http://www.spaceweather.com/')
		content = f.read()
		f.close()
		open(tmpf, 'w').write(content)
	else:
		content = open( tmpf ).read()

	s = BeautifulSoup(content)
	data = {}
	sunspot_nr = s.findAll('span', 'solarWindText')
	if sunspot_nr:
		for x in sunspot_nr:
			t = re.sub('\s+', ' ', x.text)
			if t.startswith('Solar wind'):
				windspeed = re.search('windspeed\:([0-9\.]+)', t)
				density = re.search('density\:([0-9\.]+)', t)
				if windspeed:
					data['solarwindspeed'] = windspeed.group(1)
				if density:
					data['solarwinddensity'] = density.group(1)
			elif t.startswith('Sunspot number'):
				data['sunspotnr'] = t[15:].strip()
			elif t.startswith('The Radio'):
				data['sunradio'] = t[26:].strip().replace('sfu', '')
#			else:
#				print x.text
#			print '-'*79

	if measure in data:
		print "%s.value" % measure, data[measure]

