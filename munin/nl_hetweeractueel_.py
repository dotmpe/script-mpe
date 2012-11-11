#!/usr/bin/python
import os
import time
import sys


args = list(sys.argv)
script = os.path.basename(args.pop(0))
tld_p = script.find('_')+1
host_p = script[tld_p:].find('_') + tld_p + 1

if '_' in script[host_p:]:
	measure = script[host_p:].split('_')[0]
	location = script[host_p:].split('_')[1]
else:
	location = 'amersfoort-nieuwland'
	measure = None

assert location, script[host_p:]

if measure:
	avg = measure.endswith('avg')
else:
	avg = False

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

		elif measure == 'tempavg':
			print 'graph_vlabel Temperature (C)'

			print 'temperature_weekly.label Weekly temperature trend'
			print 'temperature_weekly.type GAUGE'
			print 'temperature_weekly.cdef smoothed=x,604800,TREND'

		elif measure == 'wind':
			print 'graph_vlabel (bft)'

			print 'windspeed.label Windspeed'
			print 'windspeed.type GAUGE'

		elif measure == 'windavg':
			print 'graph_vlabel (bft)'

#			print 'windspeed_weekly.label Windspeed weekly trend'
#			print 'windspeed_weekly.type GAUGE'
#			print 'windspeed_weekly.cdef smoothed=x,604800,TREND'
#			print 'windspeed_daily.label Windspeed daily trend'
#			print 'windspeed_daily.type GAUGE'
#			print 'windspeed_daily.cdef smoothed=x,86400,TREND'
			print 'windspeed_hourly.label Windspeed hourly trend'
			print 'windspeed_hourly.type GAUGE'
			print 'windspeed_hourly.cdef smoothed=x,900,TREND'

		elif measure == 'rain':
			print 'graph_vlabel (mm)'

			print 'rain.label Precipation'
			print 'rain.type GAUGE'

		elif measure == 'rainavg':
			print 'graph_vlabel (mm)'

			print 'rain_daily.label Precipation daily trend'
			print 'rain_daily.type GAUGE'
#			print 'rain_weekly.label Precipation weekly trend'
#			print 'rain_weekly.type GAUGE'

		elif measure == 'rainavg':
			print 'graph_vlabel (mm)'

			print 'rain_weekly.label Weekly trend'
			print 'rain_weekly.cdef smoothed=x,604800,TREND'
			print 'rain_weekly.type GAUGE'

		elif measure == 'pressure':
			print 'graph_vlabel (hPa)'

			print 'pressure.label Air pressure'
			print 'pressure.type GAUGE'

		elif measure == 'sun':
			print 'graph_vlabel (W/m2)'

			print 'sunrad.label Sunshine'
			print 'sunrad.type GAUGE'

		elif measure == 'sunavg':
			print 'graph_vlabel (W/m2)'

			print 'sunrad_hourly.label Hourly trend'
			print 'sunrad_hourly.cdef smoothed=x,3600,TREND'
			print 'sunrad_hourly.type GAUGE'

		elif measure == 'uv':
			print 'graph_vlabel index'

			print 'uv_index.label UV index'
			print 'uv_index.type GAUGE'

		elif measure == 'humidity':
			print 'graph_vlabel (%)'

			print 'humidity.label Relative humidity'
			print 'humidity.type GAUGE'

		elif measure == 'humidityavg':
			print 'graph_vlabel (%)'

			print 'humidity_hourly.label Hourly trend'
			print 'humidity_hourly.cdef smoothed=x,3600,TREND'
			print 'humidity_hourly.type GAUGE'

#			print 'humidity_daily.label Daily trend'
#			print 'humidity_daily.cdef smoothed=x,86400,TREND'
#			print 'humidity_daily.type GAUGE'

else:
	import urllib2
	from BeautifulSoup import BeautifulSoup

	tmpf = '/tmp/nl-hetweeractueel-%s' % ( location )
	refresh = 5 * 60

	if not os.path.exists(tmpf) or os.path.getmtime(tmpf) + refresh < time.time():

		f = urllib2.urlopen('http://www.hetweeractueel.nl/weer/%s/actueel/' % location)
		content = f.read()
		f.close()

		open(tmpf, 'w').write(content)
	else:
		content = open(tmpf).read()

	s = BeautifulSoup(content)
	if measure.startswith('temp'):
		windchill = s.find(text='Windchill')
		if not avg and windchill:
			print 'windchill.value', windchill.parent.nextSibling.text.split(' ')[0]
		heat_index = s.find(text='Hitte index')
		if not avg and heat_index:
			print 'heat_index.value', heat_index.parent.nextSibling.text.split(' ')[0]
		temperature = s.find(text='Temperatuur')
		if temperature:
			if avg:
				print 'temperature_weekly.value', temperature.parent.nextSibling.text.split(' ')[0]
			else:
				print 'temperature.value', temperature.parent.nextSibling.text.split(' ')[0]
		dew_point = s.find(text='Dauwpunt')
		if not avg and dew_point:
			print 'dew_point.value', dew_point.parent.nextSibling.text.split(' ')[0]

	elif measure.startswith('wind'):
		windspeed = s.find(text='Windkracht')
		if windspeed:
			windspeed = windspeed.parent.nextSibling.text.split(' ')[0]
			if avg:
				print 'windspeed_hourly.value', windspeed
				print 'windspeed_daily.value', windspeed
				print 'windspeed_weekly.value', windspeed
			else:
				print 'windspeed.value', windspeed

	elif measure.startswith('rain'):
		precipation = s.find(text='Neerslag')
		if precipation:
			precipation = precipation.parent.nextSibling.text.split(' ')[0]
			if avg:
				print 'rain_daily.value', precipation
				print 'rain_weekly.value', precipation
			else:
				print 'rain.value', precipation

	elif measure.startswith('humidity'):
		humidity = s.find(text='Luchtvochtigheid')
		if humidity:
			humidity = humidity.parent.nextSibling.text.split(' ')[0]
			if avg:
				print 'humidity_hourly.value', humidity
				print 'humidity_daily.value', humidity
			else:
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

	elif measure.startswith('sun'):
		sunrad = s.find(text='Zonnestraling')
		if sunrad:
			sunrad = sunrad.parent.nextSibling.text.split(' ')[0]
			if avg:
				print 'sunrad_hourly.value', sunrad
			else:
				print 'sunrad.value', sunrad


