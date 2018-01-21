#!/usr/bin/env python
"""myCalendar - find date tags in (file)names and tables

TODO: scan for other formats, timestamps or YYYYddmm, perhaps (short)names.
"""
from __future__ import print_function
import os
import re
from pprint import pformat

import zope

from script_mpe import confparse
from script_mpe import libcmd
from script_mpe import res
from script_mpe.res import js
from script_mpe.res import primitive
from script_mpe.archive import delimiter, illegal


RE_YEAR = re.compile(r'\b([0-9]{4})\b')
RE_MONTH = re.compile(r'\b([0-9]{2})\b')
RE_DAY = re.compile(r'\b([0-9]{2})\b')


class CalendarFileTree(object):
    """
    Report on files with year, month and day (numeric only).

    - There is no further heuristics other than scans for integers of 4, 2 and 2 length,
      separated and in that sequence.
    - XXX: the singlemindedness of this implementation prevents other uses for
      numbers of 4 and 2 digits.

      - Validation has been added to relieve this somewhat.

    - This uses offset indices internally as retreived from Re matches to
      address tag spans.

    """
    def __init__(self, year_start=1900, year_end=2015):
        """
        Init new tree.
        Vary year_{start,end} for validation.
        """
        # FIXME: confparse keys are always string...
        self.tree = confparse.Values({})
        self.year_start = year_start
        self.year_end = year_end
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
        """
        Scan given (leaf) path for year/month/day tag.
        FIXME implements numeric scans only
        Upong a year match (or more), the given path is
        validated and added to the tree.
        """
        ypos, year = self.scan_year(path)
        month, day = None, None
        if ypos:
            mpos, month = self.scan_month(path, ypos+4)
            month = int(month)
            if mpos:
                dpos, day = self.scan_day(path, mpos+2)
                day = int(day)
        if year:
            year = int(year)
            self.validate(year, month, day)
            self.add(year, month, day, path)
    def walk(self, path):
        """
        Traverse subtree from directory path,
        the path of each leaf (usually a file) is then scanned.
        """
        assert os.path.isdir(path)
        for root, nodes, leafs in os.walk(path):
            for n in nodes + leafs:
                subpath = os.path.join(root, n)
                self.scan(subpath)
    def add(self, year, month, day, path):
        """
        Add path as leaf under year/month/day.
        Year must be set, others may be None.
        This does not validate the values by itself.
        """
        year = str(year)
        assert year
        if year not in self.tree:
            r = self.tree[year] = confparse.Values(dict(files=[], months={}))
        else:
            r = self.tree[year]
        if month:
            month = str(month)
            if month not in r.months:
                r = self.tree[year].months[month] = confparse.Values(dict(files=[], days={}))
            else:
                r = r.months[month]
        if day:
            day = str(day)
            if day not in r.days:
                r = self.tree[year].months[month].days[day] = confparse.Values(dict( files=[] ))
            else:
                r = r.days[day]
        assert path not in r.files
        r.files.append(path)
    def is_date(self, year, month, day):
        try:
            self.validate(year, month, day)
            return True
        except Exception as e:
            return False
    def validate(self, year, month, day):
        """For year see year_{start,end}::

            0 < month < 13
            0 < day < 32
        """
        assert year and isinstance(year, int)
        assert self.year_start < year, year
        assert year < self.year_end, year
        if month:
            assert isinstance(month, int)
            assert 13 > month > 0, month
        if day:
            assert isinstance(day, int)
            assert 32 > day > 0, day


class calendarCLI(libcmd.SimpleCommand):

    zope.interface.implements(res.iface.ISimpleCommand)

    @classmethod
    def get_optspec(klass, inherit):
        """
        """
        return (
#            (('-j', '--json'), {
#                'action': 'store',
#                'dest': 'out_format',
#            }),
#            (('-J', '--jsonxml'), {
#                'action': 'store',
#                'dest': 'out_format',
#            }),
            (('-O', '--output'), {
                'action': 'store',
                'default': 'json',
                'dest': 'out_format',
            }),
        )

    BOOTSTRAP = [ 'static_args', 'parse_options', 'set_commands' ]
    DEFAULT = [ 'run' ]

    def run(self, opts, *args):
        """
        Scan path or walk dir for each path arg.
        TODO: report format.
        """
        cft = CalendarFileTree()
        for p in args:
            print('# path:', p)
            if os.path.isdir(p):
                cft.walk(p)
            else: # must be leaf
                cft.scan(p)
        tree = cft.tree.copy(True)
        if opts.out_format == 'json':
            print(res.js.dumps(tree))
        elif opts.out_format == 'jsonxml':
            # FIXME: caltree to xmlnesting?
            sertree = res.primitive.translate_xml_nesting(tree)
            print(res.js.dumps(tree))
        else:
            print(pformat(tree))


if __name__ == '__main__':
    calendarCLI.main()
