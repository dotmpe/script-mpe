#!/usr/bin/python
# -*- coding: utf-8 -*-
import os
import time
import sys


args = list(sys.argv)
script = os.path.splitext(os.path.basename(args.pop(0)))[0]
if '_' in script and script[-1] != '_':
    obsid = script.split('_')[1]
    measure = script.split('_')[2]
else:
    obsid = '1812849'
    measure = 'temperature'


obsids = {
        'nederland/almelo/1812849': 'Almelo'
    }

obskey = None
for obskey in obsids:
    if obsid in obskey:
	break

lbl_loc = obsids[ obskey ]

url="http://www.weer.nl/verwachting/%s" % obskey
tmpf="/tmp/nl-weer-%s" % ( obsid )

if args:
    if args[0] == 'autoconf':
        print 'yes'

    elif args[0] == 'config':

        print 'graph_category weather'
        print 'graph_title Outdoor weather: %s %s' % (measure, lbl_loc)

        if measure == 'wind':
            print 'graph_vlabel (kts)'
            print 'graph_args --base 1000'

            print 'windspeed.label Windspeed'
            print 'windspeed.type GAUGE'
            print 'windgusts.label Wind gusts'
            print 'windgusts.type GAUGE'

        elif measure == 'humidity':
            print 'graph_vlabel (%)'
            print 'graph_args --base 1000'

            print 'humidity.label Relative humidity'
            print 'humidity.type GAUGE'

        elif measure == 'pressure':
            print 'graph_vlabel (hPa)'
            print 'graph_args --base 1000'

            print 'pressure.label Atmospheric pressure'
            print 'pressure.type GAUGE'

        elif measure == 'temperature':
            print 'graph_vlabel Celcius'
            print 'graph_args --base 1000 --lower-limit -4 --upper-limit 30'

            print 'temperature.label Atmospheric temperature'
            print 'temperature.type GAUGE'
#            print 'temperature.label Freezing point'
#            print 'temperature.line 0:0000bb:Freezing'
            print 'temperature.label Atmospheric Temperature %s' % (lbl_loc,)
            print 'temperature.line 28:bb0000:Tropical '

    # non munin extended script args
    elif args[0] == 'info':
	print "Observatory", obsid
	print "Key", obskey
        print 'Label', lbl_loc
	print 'URL', url
        print "Temp. file", tmpf



else:
    import urllib2
    from BeautifulSoup import BeautifulSoup

    refresh = 5 * 60

    if not os.path.exists(tmpf) or os.path.getmtime(tmpf) + refresh < time.time():

        f = urllib2.urlopen(url)
        content = f.read()
        f.close()

        open(tmpf, 'w').write(content)
    else:
	    content = open(tmpf).read()

    s = BeautifulSoup(content)

    observ = s.find('div', **{'class': 'ohwn'})

    #menu = s.find('ul', id='second_menu')
    #menu.parent.parent.parent.parent.parent.clear()

    if measure == 'wind':
        windspeed = s.find('b', text='windsnelheid')
        if windspeed:
            print 'windspeed.value', windspeed.parent.parent.nextSibling.nextSibling.text.strip().encode(enc)
        windgusts = s.find('b', text='windvlagen')
        if windgusts:
            print 'windgusts.value', windgusts.parent.parent.nextSibling.nextSibling.text.strip().encode(enc)

    elif measure == 'humidity':
        humidity = s.find('strong', text='rel. vochtigheid&nbsp;')
        if humidity:
            print 'humidity.value', humidity.parent.parent.nextSibling.nextSibling.text.strip().encode(enc)

    elif measure == 'pressure':
        pressure = s.find(text='(hPa)')
        if pressure:
            print 'pressure.value', pressure.parent.nextSibling.nextSibling.nextSibling.nextSibling.text.replace('&nbsp;', '').encode(enc)

    elif measure == 'temperature':
	temperature = observ.find("span", **{'class': "temp_val"})
        if temperature:
            print 'temperature.value', temperature.text.split(' ')[0]



