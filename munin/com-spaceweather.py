#!/usr/bin/python
import sys
import re


args = list(sys.argv)
script = args.pop(0)
if '_' in script:
	measure = script.split('_')[1]
else:
	measure = 'sunspots'

if args:
	if args[0] == 'autoconf':
		print 'yes'
	elif args[0] == 'config':

		print 'graph_category space'
		print 'graph_args --base 1000'
		print 'graph_title Space weather: %s' % (measure)

		if measure == 'sunspots':
			print 'graph_vlabel (nr)'

			print 'sunspot_nr.label Sunspot number'
			print 'sunspot_nr.type GAUGE'

else:
	import urllib2
	from BeautifulSoup import BeautifulSoup
	f = urllib2.urlopen('http://www.spaceweather.com/')
	s = BeautifulSoup(f.read())
	f.close()

	data = {}
	sunspot_nr = s.findAll('span', 'solarWindText')
	if sunspot_nr:
		for x in sunspot_nr:
			t = re.sub('\s\+', ' ', x.text)
#			if t.startswith('Solar wind'):
#				print t
#				p = t.index(':')
#				p2 = t[p+1:].index(' ')
#				windspeed = t[p+1:p+1+p2]
			if t.startswith('Sunspot number'):
				data['sunspot'] = t[15:].strip()
#			else:
#				print x.text
#			print '-'*79

	if measure == 'sunspots':
		print 'sunspot_nr.value', data['sunspot']

