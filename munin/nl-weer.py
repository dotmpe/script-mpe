#!/usr/bin/python
import os
import time
import sys


args = list(sys.argv)
script = args.pop(0)
if '_' in script:
	measure = script.split('_')[1]
	location = script.split('_')[2]
else:
	location = 'amersfoort-nieuwland'
	measure = None

if args:
	if args[0] == 'autoconf':
		print 'yes'
	elif args[0] == 'config':

		print 'graph_category weather'
		print 'graph_args --base 1000'
		print 'graph_title Outdoor weather: %s %s' % (measure, location.title())

		if measure == 'temp':
			print 'graph_vlabel Temperature (C)'

			print 'windchill.label Windchill'
			print 'windchill.type GAUGE'
			print 'temperature.label Temperature'
			print 'temperature.type GAUGE'
			print 'heat_index.label Heat index'
			print 'heat_index.type GAUGE'
			print 'dew_point.label Dew point'
			print 'dew_point.type GAUGE'

		elif measure == 'wind':
			print 'graph_vlabel (bft)'

			print 'windspeed.label Windspeed'
			print 'windspeed.type GAUGE'

		elif measure == 'rain':
			print 'graph_vlabel (mm)'

			print 'rain.label Precipation'
			print 'rain.type GAUGE'

		elif measure == 'pressure':
			print 'graph_vlabel (hPa)'

			print 'pressure.label Air pressure'
			print 'pressure.type GAUGE'

		elif measure == 'sun':
			print 'graph_vlabel (W/m2)'

			print 'sunrad.label Sunshine'
			print 'sunrad.type GAUGE'

		elif measure == 'uv':
			print 'graph_vlabel index'

			print 'uv_index.label UV index'
			print 'uv_index.type GAUGE'

		elif measure == 'humidity':
			print 'graph_vlabel (%)'

			print 'humidity.label Relative humidity'
			print 'humidity.type GAUGE'

else:
	import urllib2
	from BeautifulSoup import BeautifulSoup

	tmpf = '/tmp/nl-weer-%s' % ( location )
	refresh = 5 * 60

	if not os.path.exists(tmpf) or os.path.getmtime(tmpf) + refresh < time.time():

		f = urllib2.urlopen('http://www.hetweeractueel.nl/weer/%s/actueel/' % location)
		content = f.read()
		f.close()

		open(tmpf, 'w').write(content)
	else:
		content = open(tmpf).read()

	s = BeautifulSoup(content)
	if measure == 'temp':
		windchill = s.find(text='Windchill')
		if windchill:
			print 'windchill.value', windchill.parent.nextSibling.text.split(' ')[0]
		heat_index = s.find(text='Hitte index')
		if heat_index:
			print 'heat_index.value', heat_index.parent.nextSibling.text.split(' ')[0]
		temperature = s.find(text='Temperatuur')
		if temperature:
			print 'temperature.value', temperature.parent.nextSibling.text.split(' ')[0]
		dew_point = s.find(text='Dauwpunt')
		if dew_point:
			print 'dew_point.value', dew_point.parent.nextSibling.text.split(' ')[0]

	elif measure == 'wind':
		windspeed = s.find(text='Windkracht')
		if windspeed:
			windspeed = windspeed.parent.nextSibling.text.split(' ')[0]
			print 'windspeed.value', windspeed

	elif measure == 'rain':
		precipation = s.find(text='Neerslag')
		if precipation:
			precipation = precipation.parent.nextSibling.text.split(' ')[0]
			print 'rain.value', precipation

	elif measure == 'humidity':
		humidity = s.find(text='Luchtvochtigheid')
		if humidity:
			humidity = humidity.parent.nextSibling.text.split(' ')[0]
			print 'humidity.value', humidity

	elif measure == 'pressure':
		pressure = s.find(text='Barometer')
		if pressure:
			print 'pressure.value', pressure.parent.nextSibling.text.split(' ')[0]

	elif measure == 'uv':
		uv_index = s.find(text='UV index')
		if uv_index:
			uv_index = uv_index.parent.nextSibling.text.split(' ')[0]
			print 'uv_index.value', uv_index

	elif measure == 'sun':
		sunrad = s.find(text='Zonnestraling')
		if sunrad:
			sunrad = sunrad.parent.nextSibling.text.split(' ')[0]
			print 'sunrad.value', sunrad


