#!/usr/bin/env python
"""myCalendar - 
"""
import os
import re
import optparse
from pprint import pformat

import zope

import libcmd
import res

from archive import delimiter, illegal

RE_YEAR = re.compile(r'\b([0-9]{4})\b')
RE_MONTH = re.compile(r'\b([0-9]{2})\b')
RE_DAY = re.compile(r'\b([0-9]{2})\b')


class CalendarFileTree(object):
    """
    Report on files with year, month and day (numeric only).

    - There is no further semantics other than integers of 4, 2 and 2 length,
      separated and in that sequence.
    - TODO: Validation of found date  
    - FIXME: the singlemindedness of this implementation prevents other uses for 
      numbers of 4 and 2 digits.
    - This uses some offset indices internally only. Is using parallel markup
      for paths a way to go to indicate (proper) semantics of embedded tags?

    """
    def __init__(self):
        self.tree = {}
    def scan_year(self, path, offset=0):
        m = RE_YEAR.search(path[offset:])
        if m:
            return offset+m.start(0), m.groups()[0]
        else:
            return offset, None
    def scan_month(self, path, offset=0):
        m = RE_MONTH.search(path[offset:])
        if m:
            return offset+m.start(0), m.groups()[0]
        else:
            return offset, None
    def scan_day(self, path, offset=0):
        m = RE_DAY.search(path[offset:])
        if m:
            return offset+m.start(0), m.groups()[0]
        else:
            return offset, None
    def scan(self, path):
        ypos, year = self.scan_year(path)
        month, day = None, None
        if ypos:
            mpos, month = self.scan_month(path, ypos+4)
            if mpos:
                dpos, day = self.scan_day(path, mpos+2)
        if year:
            self.add(year, month, day, path)
    def walk(self, path):
        assert os.path.isdir(path)
        for root, nodes, leafs in os.walk(path):
            for n in nodes + leafs:
                subpath = os.path.join(root, n)
                self.scan(subpath)
    def add(self, year, month, day, path):
        assert year
        self.validate(year, month, day)
        if year not in self.tree:
            r = self.tree[year] = optparse.Values(dict(files=[], months={}))
        else:
            r = self.tree[year]
        if month:
            if month not in r.months:
                r = self.tree[year].months[month] = optparse.Values(dict(files=[], days={}))
            else:
                r = r.months[month]
        if day:
            if day not in r.days:
                r = self.tree[year].months[month].days[day] = optparse.Values(dict( files=[] ))
            else:
                r = r.days[day]
        assert path not in r.files
        r.files.append(path)
    def validate(self, year, month, day):
        assert year
        pass


class calendarCLI(libcmd.SimpleCommand):

    zope.interface.implements(res.iface.ISimpleCommand)

    @classmethod
    def get_optspec(klass, inherit):
        """
        """
        return ()

    DEFAULT_ACTION = 'run_'

    def run_(self, *args):
        cft = CalendarFileTree()
        for p in args:
            if os.path.isdir(p):
                cft.walk(p)
            else: # must be leaf
                cft.scan(p)
        print pformat(cft.tree)

if __name__ == '__main__':
    calendarCLI.main()

