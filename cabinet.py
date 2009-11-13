#!/usr/bin/env python
"""cabinet - Search and tag for archived, tagged paths. 

Wrapper around GNU find.
.. `POSIX 'find'`__. incompat. no iregex, no iname, just name.

Cabinet paths are semi-structured paths with tags.

Tags are alfanumeric parts of paths, on both sides delimited by non-alfanumeric 
characters. These are used for looking op certain types of paths.

Such paths can in addition have up to three archive tags may be present: fully 
numeric sequences in a hierarchical structure: Year (four digits), Month, and Day 
(both two digits).

These may appear in given order only, but only the Year tag is required.
This is the 'archive Date' of the path, or when it was created/archived while
any file stat-info indicates its last update. Also collected is the modified
date of the path from its inode stat info.

The result is a table with fields 
Each result list is printed to output according to a given format. 


Ideas:
    - implement filters based on given tag spec.

.. __: http://www.opengroup.org/onlinepubs/009695399/utilities/find.html
"""
import os, sys, re, datetime, optparse


DATE_FORMAT = "%(year)s-%(month)s-%(day)s"

SORT_DATE = 'date'
SORT_UPDATE = 'update'

ASC = 1
DESC = 2

TAB = '\t'
#CRLF = '\r\n'


def last_update(path):
    """
    Return modified date in three strings: year, month and day.
    """

    tstamp = os.path.getmtime(path)
    date = datetime.date.fromtimestamp(tstamp)
    return "%s" % date.year, "%#02i" % date.month, "%#02i" % date.day


class CabinetQuery:

    sorts = (SORT_DATE, DESC)
    date_separator = '-'

    def __init__(self, directory):
        self.directory = directory
        self.tags = []

    def add_include(self, tagspec):
        if '+' in tagspec:
            path = tagspec.split('+')
        else:
            path = [tagspec]
        self.tags.append(path)

    def set_sort(self, sortspec):
        sorts = sortspec.split(',')
        self.sort_order = sort_order

    EGREP_LBOUND = r'(^|(.*?[^a-zA-Z0-9]))+'
    EGREP_MID = r'[^a-zA-Z0-9](.*?[^a-zA-Z0-9])?'
    EGREP_RBOUND = r'($|([^a-zA-Z0-9].*?))+'
    EGREP_ARCHIVE = r'^%s([0-9]{4})(%s([0-9]{2})){0,2}%s$' % (EGREP_LBOUND, EGREP_MID, EGREP_RBOUND)
	#EGREP_ARCHIVE = r'^%s([0-9]{4})[^a-zA-Z0-9](([0-9]{2})|([^a-zA-Z0-9].*?)){0,2}%s$' % (EGREP_LBOUND, EGREP_RBOUND)

    EGREP_ARCHIVE = r'^.*?([0-9]{4}).*?([0-9]{2}).*?([0-9]{2}).*$'

    def run(self):

        """
        Scan current directory.
        """

		# FIXME: this isn't working, replace with native regex?
        cmd = 'find -L "%s" -regextype posix-egrep ' % self.directory
        for path in self.tags:
            if len(path) > 1:
                cmd = cmd + ' -iregex "^%s%s' % (self.EGREP_LBOUND, path.pop(0))
                for tag in path:
                    cmd = cmd + '%s%s' % (self.EGREP_MID, tag)
                cmd = cmd + '%s$"' % self.EGREP_RBOUND
            else:
                cmd = cmd + ' -iregex "^%s%s%s$" ' % (self.EGREP_LBOUND,
                        path.pop(), self.EGREP_RBOUND)

        fi,fo,fe = os.popen3(cmd)
        paths = [line.strip() for line in fo.readlines()]
        status = fo.close()
        if status:
            #print >>sys.stderr, fe.read()
            raise "Error %i while running '%s'" % (status, cmd)

        return paths

    def finalize(self):

        """
        Return archive date, modified date and path for each match.
        """

        paths = self.run()
        for path in paths:
            date = ''
            m = re.match(self.EGREP_ARCHIVE, path)
            if m:
                date = self.date_separator.join(m.groups())
            update = ''
            if os.path.exists(path):                
                update = self.date_separator.join(last_update(path))
            yield date, update, path


class ResultPrinter:

    separator = TAB

    def __init__(self, results):
        self.results = results

    def set_format(self, name): 
        self.__format = name

    def format_line(self, *fields):
        return self.separator.join(fields)

    def flush(self):
        print self.format(self.__format)

    def format(self, format):
        out = []
        if format == 'table':
            out = [ self.format_line('# archived', 'modified', 'path') ] +\
                    [ self.format_line(*fields) for fields in self.results ]
        elif format == 'path':
            out = [ fields[2] for fields in self.results ]

        return '\n'.join(out)


usage_descr = """%prog [options] """
"""XXX: alt argv: [[dir] [+tag+tag.. -tag+tag..]].." """

options_spec = (
    (('-t', '--tagged'), {'metavar':'TAGS', 'action':'append', 'help':
        "Filter on tag. Multiple occurences allowed, each occurence matches on the entire path. "
        "Eg. -t=foo -t=bar matches on an occurence of 'foo' and 'bar', anywhere in the path, "
        "while -t=foo+bar also matches on the given order of tags. "
        "Tags must be delimited by non alfanumeric characters. " }),
    (('-n', '--nottagged'), {'metavar':'TAGS', 'action':'append', 'help':
        "Inverse of --tagged, exclude matching paths from result. " }),

    (('-d', '--date-separator'), {'default': CabinetQuery.date_separator, 'help':
        "Used when autoformatting a path. " }),

    (('-F', '--format'), {'default': 'path', 'help':
        "Set the output format (default:%default)" }),
    (('-f', '--field-separator'), {'default': ResultPrinter.separator, 'help':
        "Set the field deliter used to separate columns (default:%default)" }),

    (('-u', '--updated'), {'help':
        "Filter output list to include only entries modified within specified date range. "
        "Requires at least the year. Month and day are separated by comma." }),
    (('-e', '--entries'), {'help':
        "Filter output list to include only entries from within specified date range. " }),

    (('-s', '--sort'), {'help':
        "Sort output list on property with order in given priority. "
        "=date:asc,update:asc" }),
)

def main():
    root = os.getcwd()
    cab = CabinetQuery(root)

    prsr = optparse.OptionParser(usage=usage_descr)
    for a,k in options_spec:
        prsr.add_option(*a, **k)
    opts, args = prsr.parse_args(sys.argv)

    args.pop(0)

    for tag_spec in opts.tagged:
        cab.add_include(tag_spec)

#    for tag_spec in opts.nottag:
#        cab.add_exclude(tag_spec)

    # output results
    printer = ResultPrinter(list(cab.finalize()))
    printer.set_format(opts.format)
    printer.flush()

#    args = sys.argv[1:]
#    while args:
#        a = args.pop()
#        elif a.startswith('--date-format') or a.startswith('-f'):
#            if not '=' in a:
#                fmt = args.pop()
#            else:
#                fmt = a.split('=').pop()
#            cab.set_format(fmt)
#        elif a.startswith('--sort') or a.startswith('-s'):
#            if not '=' in a:
#                sort_on = args.pop()
#            else:
#                sort_on = a.split('=').pop()
#            cab.add_sort(sort_on)
#        elif a.startswith('--entries') or a.startswith('-e'):
#            if not '=' in a:
#                entries = args.pop()
#            else:
#                entries = a.split('=').pop()
#            cab.set_list(entries)
#        elif a.startswith('--updated') or a.startswith('-u'):
#            if not '=' in a:
#                updated = args.pop()
#            else:
#                updated = a.split('=').pop()
#            cab.set_list(updated)
#        elif a.startswith('--desc') or a.startswith('-d'):
#            cab.set_sort(cab.SORT_DESC)
#        elif a.startswith('--asc') or a.startswith('-a'):
#            cab.set_sort(cab.SORT_ASC)


if __name__ == '__main__':
    main()
