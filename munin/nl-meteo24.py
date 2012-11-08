#!/usr/bin/python
import os
import time
import sys


args = list(sys.argv)
script = args.pop(0)
if '_' in script:
	measure = script.split('_')[1]
	obsid = script.split('_')[2]
else:
	obsid = '31X4383'
	measure = 'wind'

obsids = {
		'31X4383': 'Twente, Overijssel (6.9E 52.22N 46m)'
	}

lbl_loc = obsids[ obsid ]

if args:
	if args[0] == 'autoconf':
		print 'yes'
	elif args[0] == 'config':

		print 'graph_category weather'
		print 'graph_args --base 1000'
		print 'graph_title Outdoor weather: %s %s' % (measure, lbl_loc)

		if measure == 'wind':
			print 'graph_vlabel (kts)'

			print 'windspeed.label Windspeed'
			print 'windspeed.type GAUGE'
			print 'windgusts.label Wind gusts'
			print 'windgusts.type GAUGE'

		elif measure == 'humidity':
			print 'graph_vlabel (%)'

			print 'humidity.label Relative humidity'
			print 'humidity.type GAUGE'

		elif measure == 'pressure':
			print 'graph_vlabel (hPa)'

			print 'pressure.label Atmospheric pressure'
			print 'pressure.type GAUGE'

else:
	import urllib2
	from BeautifulSoup import BeautifulSoup

	tmpf = '/tmp/nl-meteo24-%s' % ( obsid )
	refresh = 5 * 60

	if not os.path.exists(tmpf) or os.path.getmtime(tmpf) + refresh < time.time():

		f = urllib2.urlopen('http://www.meteo24.nl/nl/%s.html' % obsid)
		content = f.read()
		f.close()

		open(tmpf, 'w').write(content)
	else:
		content = open(tmpf).read()

	s = BeautifulSoup(content)

	menu = s.find('ul', id='second_menu')
	menu.parent.parent.parent.parent.parent.clear()

	if measure == 'wind':
		windspeed = s.find('b', text='windsnelheid')
		if windspeed:
			print 'windspeed.value', windspeed.parent.parent.nextSibling.nextSibling.text.strip()
		windgusts = s.find('b', text='windvlagen')
		if windgusts:
			print 'windgusts.value', windgusts.parent.parent.nextSibling.nextSibling.text.strip()

	elif measure == 'humidity':
		humidity = s.find('strong', text='rel. vochtigheid&nbsp;')
		if humidity:
			print 'humidity.value', humidity.parent.parent.nextSibling.nextSibling.text.strip()

	elif measure == 'pressure':
		pressure = s.find(text='(hPa)')
		if pressure:
			print 'pressure.value', pressure.parent.nextSibling.nextSibling.nextSibling.nextSibling.text.replace('&nbsp;', '')

