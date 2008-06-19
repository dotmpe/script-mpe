#!/usr/bin/env python
"""Relink symbolic links using regular expressions.
"""
import os
import sys
import re

usage = "Usage: % relink match replace [- | links...]"
noact = False
if not len(sys.argv)>3:
	sys.exit(usage)

if sys.argv[3] == '-':
	links = sys.stdin.read().split('\0')
else:
	links = sys.argv[3:]

if '-n' in sys.argv:
	noact = True


find, replace = sys.argv[1:3]

find = re.compile(find)

pwd = os.getcwd()

for link in links:
	link = link.strip(' \n\r\0\t')
	if not link:	
		continue

	target = os.readlink(link)
	if find.match(target):

		linkdir = os.path.dirname(link)
		if linkdir:
			os.chdir(linkdir)

		linkname = os.path.basename(link)
		ntarget = find.sub(replace, target)

		if noact:
			print 'ln -s ', ntarget, linkname
		else:
			os.unlink(linkname)
			os.symlink(ntarget, linkname)

	os.chdir(pwd)




