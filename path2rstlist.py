#!/usr/bin/env python
"""Convert the path component of a filename, relative to the htdocs root to an linked rst list.

XXX: simple standalone script, prolly doesn't need RDF integration, but anyway
"""
import sys
from os.path import exists, split, sep, isdir, join, splitext

if __name__ == '__main__':
	args = sys.argv
	assert len(args)>1, "to few arguments in %s" % args

	path = args.pop()
	#assert exists(path), "%s does not exist" % path

	dir, name = split(path)
	dirs = []
	if dir:
		#assert isdir(dir), "%s not a dir" % dir
		dirs = dir.split(sep)

	pathsegments = len(dirs)
	rstlist = []
	while dirs:
		dn = dirs.pop()
		if dn:
			pathsegments -= 1
			rstlist.append("%i. `%s <%s>`_%s" % (pathsegments, dn, sep.join(dirs+[dn]), sep))
	pathsegments -= 1
	rstlist.append("%s. `%s <%s>`_" % (pathsegments, sep, sep))

	name, ext = splitext(name)

	rstlist.reverse()
	rstlist.append("%i. %s" % (len(dir.split(sep)), name))

	print "\n.. header::\n\t\n\t",
	print "\n\t".join(rstlist)
	print
