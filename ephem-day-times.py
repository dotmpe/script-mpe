#!/usr/bin/env python3
"""
Print table with twillight and suntimes in GMT and local time.
All parameters are from the environment, except the first argument is parsed
as date and an optional prefix.

Prefixing with 'daytime' or 'nighttime' silences the progam and instead tests
wether the given datetime is day or nighttime and exits non-zero otherwise.

Usage:
  ephem-day-times.py [daytime|nighttime] [<Datetime>]
  ephem-day-times.py help

Environment:
  GEO_HOME provide lat-long pair in decimal separated by comma
  HORIZON set horizon angle. Normally day start/end are at 0 degrees, but other
    values may be appropiate to get actual daylight conditions (ie. 3 or 6).
  TWILLIGHT_HORIZON set angle to compute twillight (default is -6 degrees).
"""
import os
import sys
import ephem
import time
from datetime import datetime, tzinfo
from dateutil import parser, tz
import pytz
from pytz import timezone


args = sys.argv[:]
script = args.pop(0)
cmd = 'printtable'
if len(args) > 0:
    if args[0] == "help":
        print(__doc__)
        sys.exit()
    elif args[0] in ("daytime","nighttime"):
        cmd = args.pop(0)

if 'GEO_HOME' in os.environ:
    latlong = os.environ['GEO_HOME'].split(',')
else:
    sys.exit("Please provide latlong setting")

tzinfos = {'EST': tz.gettz(time.tzname[0]),
           'EDT': tz.gettz(time.tzname[0])}

if len(args) > 0:
    # XXX: Ephem eats UTC dates...
    dt = parser.parse(args.pop(0), tzinfos=tzinfos)
else:
    dt = datetime.now(timezone('utc'))


loc = ephem.Observer()

if cmd == 'printtable':
    # Set to noon for proper table
    dt = dt.replace(hour=15, minute=0, second=0, microsecond=0)

loc.date = ephem.Date(dt)
# No elevation or horizon added.. yet

loc.pressure = 0
loc.lat, loc.lon = latlong

loc_horizon = os.environ.get('HORIZON', '0')
twillight_horizon = os.environ.get('TWILLIGHT_HORIZON', '-6')

sun = ephem.Sun()

if cmd == 'daytime':
    # For daytime or nighttime determination we want to compare
    # if next sunset is before next sunrise (daytime)
    # or if next sunrise is before next sunset (nighttime)

    loc.horizon = loc_horizon
    if loc.next_rising(sun) < loc.next_setting(sun):
        sys.exit(1)
    else:
        sys.exit(0)

elif cmd == 'nighttime':
    loc.horizon = loc_horizon
    if loc.next_rising(sun) < loc.next_setting(sun):
        sys.exit(0)
    else:
        sys.exit(1)

elif cmd == 'twillight':
    loc.horizon = twillight_horizon
    # TODO:

else:
    print('# dates')
    print(dt.astimezone(timezone('utc')), 'now GMT')
    print(dt.astimezone(), 'now local')

    loc.horizon = twillight_horizon
    sunrise = loc.previous_rising(sun, use_center=True)
    sunset = loc.next_setting(sun, use_center=True)

    sunrisedt = pytz.utc.localize(sunrise.datetime())
    sunsetdt = pytz.utc.localize(sunset.datetime())

    print('# twillight ')
    print(sunrise.datetime(), 'begin twillight GMT')
    print( sunset.datetime(), 'end twillight GMT')

    print(sunrisedt.astimezone(), 'begin twillight local')
    print( sunsetdt.astimezone(), 'end twillight local')

    loc.horizon = loc_horizon
    sunrise = loc.previous_rising(sun)
    noon = loc.next_transit(sun, start=sunrise)
    sunset = loc.next_setting(sun)

    print('#')
    print(sunrise.datetime(), 'sunrise GMT')
    print(   noon.datetime(), 'noon GMT')
    print( sunset.datetime(), 'sunset GMT')

    print('# timezone is', time.tzname[0])

    sunrisedt = pytz.utc.localize(sunrise.datetime())
    noondt = pytz.utc.localize(noon.datetime())
    sunsetdt = pytz.utc.localize(sunset.datetime())

    print(sunrisedt.astimezone(), 'sunrise local')
    print(   noondt.astimezone(), 'noon local')
    print( sunsetdt.astimezone(), 'sunset local')
