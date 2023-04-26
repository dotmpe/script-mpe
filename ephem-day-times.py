#!/usr/bin/env python3
"""
Determine the time of day according to an atronomical model.
A simple script using the Ephem library.

Usage:
  ephem-day-times.py [<command>] [<Datetime>]
  ephem-day-times.py help

All parameters are from the environment, but the first argument to a command
must be a date else the current system time is used.

The default command is 'table'.

All calculations are done by creating an Ephem observer with geographic location
and given time, and a Sun or Moon object for that observer to determine its
coordinates or compare rise/set times for some horizon. For the rise and set
time of an object, the moment its edge crosses the horizon is used. For the
start of twillight (dusk and dawn) the Sun's center is used in the calculation.

(Note that date-times in most comments will be GMT)

Commands:
  - daytime - tests next sunset is before sunrise
  - nighttime - tests next sunrise is before sunset
  - twillight - tests for and reports dusk or dawn (but not day or night)
  - night - tests for actual nighttime (night excluding twillight)
  - sun - report RA,DEC,AZ,ALT for sun
  - moon - report RA,DEC,AZ,ALT for moon
  - tags - report tags associated with current time of day

Environment:
  GEO_LOC provide lat-long pair in decimal separated by comma
  HORIZON set horizon angle. Normally day start/end are at 0 degrees, but other
    values may be appropiate to get actual daylight conditions depending on
    local horizon.
  TWILLIGHT_HORIZON set angle to compute twillight (default is -6 degrees).
    Three common values are -9, -6, and -3 for astronomical, nautical, or civil.
  COORD set coordinate system for reporting degrees, 1 for local Az-Alt or
    2 for celestial RA-Dec or 3 for all [default: 3].
  DEGREES set to 1 to use degree instead of time notation for degrees.
  SHIFT_TIME Advance or delay given or current time by seconds

TBD:
    - Direction of object for rise/set at local horizon
    - Separate local horizon for dusk and dawn could be NTH but might use
      lists for relevant degrees/segments?
"""
import os
import sys
import ephem
import time
from datetime import datetime, tzinfo
from dateutil import parser, tz
import pytz
from pytz import timezone
import numpy as np


def sun_table(dt, loc_horizon, twillight_horizon):
    print('# Ephem Sun table for', dt.astimezone().date())
    print('# Position: %s, %s' % latlong )
    print('# Elevation: %s' % 0)
    print('# Local horizon: %s' % loc_horizon)
    print('# Twillight horizon: %s' % twillight_horizon)
    print('# ')

    loc.horizon = loc_horizon
    sunrise = loc.previous_rising(sun)
    noon = loc.next_transit(sun, start=sunrise)
    sunset = loc.next_setting(sun)

    loc.horizon = twillight_horizon
    dusk = loc.next_setting(sun, use_center=True)
    midnight = loc.next_antitransit(sun)
    dawn = loc.previous_rising(sun, use_center=True)

    print('# sun UTC')

    print(    dawn.datetime(), 'begin twillight GMT')
    print( sunrise.datetime(), 'sunrise GMT')
    print(    noon.datetime(), 'noon GMT')
    print(  sunset.datetime(), 'sunset GMT')
    print(    dusk.datetime(), 'end twillight GMT')
    print(midnight.datetime(), 'midnight GMT')

    localtz = time.tzname[0]
    print('# sun local', localtz)

    dawndt = pytz.utc.localize(dawn.datetime())
    midnightdt = pytz.utc.localize(midnight.datetime())
    duskdt = pytz.utc.localize(dusk.datetime())

    sunrisedt = pytz.utc.localize(sunrise.datetime())
    noondt = pytz.utc.localize(noon.datetime())
    sunsetdt = pytz.utc.localize(sunset.datetime())

    print(    dawndt.astimezone(), 'begin twillight local %s' % localtz)
    print( sunrisedt.astimezone(), 'sunrise local %s' % localtz)
    print(    noondt.astimezone(), 'noon local %s' % localtz)
    print(  sunsetdt.astimezone(), 'sunset local %s' % localtz)
    print(    duskdt.astimezone(), 'end twillight local %s' % localtz)
    print(midnightdt.astimezone(), 'midnight local %s' % localtz)

    print('# ')
    print("# Day: %s hours" % (24 * (sunset - sunrise)))
    print("# Daylight: %s hours" % (24 * (dusk - dawn)))
    print("# Morning: %s hours" % (24 * (noon - sunrise)))
    print("# Afternoon/evening: %s hours" % (24 * (sunset - noon)))
    print("# Evening: %s hours" % (24 * (noon - sunrise)))


def get_daytime(sun, loc_horizon, twillight_horizon):
    loc.horizon = loc_horizon
    if loc.next_rising(sun) < loc.next_setting(sun):

        # Night time; twillights ends and starts at negative horizon
        loc.horizon = twillight_horizon

        if loc.next_rising(sun, use_center=True) < loc.next_setting(sun,
                use_center=True):

            # Past dusk
            if loc.next_setting(sun, use_center=True) < loc.next_rising(sun,
                    use_center=True):

                # Past break of dawn
                return 'dawn'
        else:
            return 'dusk'
    else:
        return 'daytime'

def get_tags(sun, loc_horizon, twillight_horizon):

    print('# now', loc.date)
    tag = get_daytime(sun, loc_horizon, twillight_horizon)
    if not tag:
        tag = 'nighttime'
    tags = [tag]

    # Window in days
    near_window = 0.03 # 43min
    near_window = 0.04 # about an hour
    near_window = 0.06 # about 1.5 hour

    start_evening = 18

    loc.horizon = loc_horizon
    sunrise = loc.previous_rising(sun)
    if tag == 'daytime':
        noon = loc.next_transit(sun, start=sunrise)
        print('# noon', noon)
        if loc.date < noon:
            if loc.date + near_window > noon:
                tags.append("nearly+noon")
            elif loc.date - near_window < sunset:
                tags.append("early+morning")
            else:
                tags.append("morning")
        else:
            if loc.date - near_window < noon:
                tags.append("early+afternoon")
            elif dt.hour < start_evening:
                tags.append("afternoon")
            else:
                #if loc.date - near_window
                tags.append("evening")
    else:
        midnight = loc.next_antitransit(sun)
        print('# midnight', midnight)
        if tag == 'dusk':
            tags.append('late+evening')
        elif tag == 'dawn':
            pass
        else:
            if loc.date < midnight:
                if loc.date + near_window > midnight:
                    tags.append('near+midnight')
            else:
                if loc.date - near_window < midnight:
                    tags.append("early+night") # Small hours

    return tags



cmds=("daytime","nighttime","twillight","night","sun","moon","tags","table",
        "solar-time")

args = sys.argv[:]
script = args.pop(0)
if not len(args):
    cmd = 'table'
elif args[0] == "help":
    print(__doc__)
    sys.exit()
elif args[0] in cmds:
    cmd = args.pop(0)
else:
    print("Usage: %s", " | ".join(cmds))
    sys.exit(1)

if 'GEO_LOC' in os.environ:
    latlong = tuple(os.environ['GEO_LOC'].split(','))
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

if cmd == 'table':
    # Set to noon for proper table
    dt = dt.replace(hour=15, minute=0, second=0, microsecond=0)

loc.date = ephem.Date(dt)

shift_seconds = int(os.environ.get('SHIFT_TIME', '0'))
if shift_seconds:
    shift_days = shift_seconds / 86400
    loc.date += shift_days

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
    if loc.next_setting(sun) < loc.next_rising(sun):
        sys.exit(0)
    else:
        sys.exit(1)

elif cmd == 'nighttime':

    loc.horizon = loc_horizon
    if loc.next_rising(sun) < loc.next_setting(sun):
        sys.exit(0)
    else:
        sys.exit(1)

elif cmd == 'twillight':
    # By lowering the horizon to a negative degree the sunrise/sunset
    # can be used to indicate the start or end of twillight.

    tag = get_daytime(sun, loc_horizon, twillight_horizon)
    if tag in ('dusk', 'dawn'):
        print(tag)
    else:
        sys.exit(1)

elif cmd == 'night':
    # For actual night we exclude twillight from nighttime as well.

    if get_daytime(sun, loc_horizon, twillight_horizon):
        sys.exit(1)

elif cmd in ('sun', 'moon'):

    COORD = int(os.environ.get('COORD', '3'))

    if cmd == 'sun':
        sun = ephem.Sun(loc)
        if COORD == 1:
            coords = (sun.az, sun.alt)
        elif COORD == 2:
            coords = (sun.ra, sun.dec)
        elif COORD == 3:
            coords = (sun.az, sun.alt, sun.ra, sun.dec)
        else: sys.exit(1)

    else:
        moon = ephem.Moon(loc)
        if COORD == 1:
            coords = (moon.az, moon.alt)
        elif COORD == 2:
            coords = (moon.ra, moon.dec)
        elif COORD == 3:
            coords = (moon.az, moon.alt, moon.ra, moon.dec)
        else: sys.exit(1)

    if int(os.environ.get('DEGREES', '0')) == 1:
        coords = list(map(np.degrees, coords))

    sep = os.environ.get('SEPARATOR', ' ')

    print(sep.join(["%s" % s for s in coords]))

elif cmd in ('tags',):
    print(*get_tags(sun, loc_horizon, twillight_horizon))


elif cmd in ('table',):

    sun_table(dt, loc_horizon, twillight_horizon)

    #moon_table(dt, loc_horizon)

elif cmd in ('solar-time'):
    sun.compute(dt)
    ra, dec = loc.radec_of('0', '-90')

    print('# %s Date/time:' % time.tzname[0], dt.astimezone())
    print('# Sun right ascension:', sun.ra)
    print('# Local nadir right ascension:', ra)
    print('# Solar time:')
    print(ephem.hours((ra - sun.ra) % (2 * ephem.pi)), 'hours')
