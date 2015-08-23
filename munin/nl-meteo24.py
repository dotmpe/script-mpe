#!/usr/bin/python
# -*- coding: utf-8 -*-
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

enc = 'utf-8'

obsids = {
        '31X4383': 'Twente, Overijssel (6.9E 52.22N 46m)',
        '31X4825': 'Amsterdam, Noord-Holland (4.89E 52.37N 3m)',
        '31X7099': 'Eelde, Groningen (6.55E 53.22N)',
        '31X1276': 'Vlissingen, Zeeland (3.58E 51.45N)',
        '31X1235': 'Eindhoven, Noord-Brabant (5.47E 51.45N)',
        '31X155': 'Maastricht, Limburg (5.68E 50.85N)',
    }

lbl_loc = obsids[ obsid ]

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
        temperature = s.find(text=u'&nbsp;(°C)&nbsp;')
        if temperature:
            print 'temperature.value', temperature.parent.nextSibling.nextSibling.text.replace('&nbsp;', '').encode(enc)

