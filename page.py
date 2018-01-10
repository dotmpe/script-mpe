#!/usr/bin/env python
"""page - read specific pages from a file.
"""
from __future__ import print_function
import sys, optparse


default_file = '-'
default_separator = '\f'

argv_usage = """%prog [options] [-|file] [pagenr ...]

One file argument is accepted, followed by page numbers. Implicitly this sets
the according named options, which may be used directly for an alternative
invocation, see ``--help``. However, if there are any arguments the first MUST
be the filename. This input file defaults to stdin. To request any pages without
specifying filename, the named option (``--pages``) must be used.
"""
argv_options = (
        (('-p','--page'), {'help':'One or more pages to display',
            'action':'append','type':'int','dest':'page_numbers','default':[]}),
        (('-s','--page-separator'), {'help':'Sequence for separating pages.',
            'default':default_separator,'metavar':'CHARS'}),
        (('-f','--file'), {'help':'The file to read pages from (default: %default).',
            'default':default_file}),
        (('-S','--print-separator'), {'help':'Wether to print the page separator sequence or omit it.',
            'action':'store_true','default':False}),
    )


if __name__ == '__main__':
    prsr = optparse.OptionParser(argv_usage)
    for opt, spec in argv_options:
        prsr.add_option(*opt, **spec)
    opts, args = prsr.parse_args()

    if args:
        assert opts.file == default_file
        opts.file = args.pop(0)
    while args:
        opts.page_numbers.append(int(args.pop(0)))

    if opts.file == '-':
        pages = sys.stdin.read().split(opts.page_separator)
    else:
        pages = open(opts.file).read().split(opts.page_separator)

    for page in opts.page_numbers:
        try:
            print(pages[page-1].strip())
            if opts.print_separator:
                print(opts.page_separator)
        except IndexError:
            print('No such page: %s' % page, file=sys.stderr)
