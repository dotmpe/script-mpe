#!/usr/bin/env python3
import os, re, sys
from pprint import pprint
from Xlib import display
from Xlib.ext import randr
from script_mpe.res import js


def outputs ():

    d = display.Display(os.getenv('DISPLAY', ':0'))
    w = d.screen(0).root
    r = randr.get_screen_resources(w)
    ts = 0 #r['config_timestamp']

    print('# Window ID, Output ID, Name, Width, Height')
    for output in r.outputs:
        oi = randr.get_output_info(w, output, ts)
        print(hex(w.id), hex(output), oi.name, oi.mm_width, oi.mm_height)


def ls (data_file=None):
    """
    Rough attempt to output structured object for xrandr --verbose output.
    """
    data = {}
    d = None
    p = None
    screennr = None
    linkname = None
    indent = None
    strip_properties = [] # 'EDID'

    if data_file:
        lines = open(data_file).readlines()
    else:
        lines = os.popen('xrandr --verbose').readlines()

    for line in lines:
        if line.startswith('Screen '):
            screennr = line.split(' ')[1]
            data[screennr] = {}

        elif re.match(r'^[A-Za-z]', line):
            linkname = line.split(' ')[0]
            data[screennr][linkname] = d = {}

        # skip modes
        elif re.match(r'^[\t ]*[0-9]+x[0-9]+ \(0x', line):
            p = None

        else:
            indent = len(re.match(r'^[ \t]+', line).group(0))

            if indent == 1 and ':' in line:
                p, v = map(str.strip, line.split(':', maxsplit=1))
                d[p] = v

            elif indent > 1 and p:
                if p in strip_properties:
                    d[p] += line.strip()
                else:
                    d[p] += ' '+line.strip()

    js.dump(data)


if __name__ == '__main__':
    args = sys.argv[1:]

    if not args:
        args = ['outputs']

    h = globals()[args[0]]
    h(*args[1:])
