#!/usr/bin/env python
"""
Decode HTML/XML? entities from string.

Usage:
	xml-decode [xml-encoded-file | -]...
"""
import os, sys

try:
    # Python 2.6-2.7
    from HTMLParser import HTMLParser
except ImportError:
    # Python 3
    from html.parser import HTMLParser

h = HTMLParser()

args = sys.argv[1:]
if '-?' in args or '-h' in args:
    print(__doc__)
    sys.exit(0)
if not args:
    print(__doc__)
    sys.exit(1)
	#args = ['-']
for a in args:
	if a == '-':
		print(h.unescape(sys.stdin.read()))
	else:
		print(h.unescape(open(a).read()))
