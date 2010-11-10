#!/usr/bin/env python
import os, sys, re, anydbm
from os.path import join


def find_other_paths(fn):
	"""
	For each symbolic link to a directory, a subtree is cloned in the address
	space.
	Given path `fn`, this traverses all symbolic links and returns the
	'alternative' paths to `fn`.

	This does not find all paths that are linked to `fn`.
	"""
	print fn

	samefn = []
	suppath = fn.split(os.sep)
	subpath = []
	while suppath:
		path = os.sep.join(suppath)
		if os.path.islink(path):
			link = os.readlink(path)
			if not link.startswith(os.sep):
				if os.path.isfile(path):
					path = os.path.dirname(path)
					pass
				#print os.path.join(path,link),os.path.normpath(os.path.join(path,link))
				link = os.path.normpath(os.path.join(path,link))
			assert os.path.exists(link), "Broken link %s to %s" % (path, link)
			if os.path.isdir(path):
				samefn.extend(find_other_paths(link))
			else:
				samefn.append(link)
			if os.path.islink(link):
				print 'next link', link
		subpath.append(suppath.pop())
	return samefn


def main():
	if sys.argv:
		paths = sys.argv[1:]
	else:		
		paths = [os.getcwd()]
	for p in paths:
		if os.path.isdir(p):
			for root, dirs, files in os.walk(p):
				for fn in files:
					print find_other_paths(join(root, fn))
		else:
			print find_other_paths(p)


if __name__ == '__main__':
	main()

# vim:set noet:
