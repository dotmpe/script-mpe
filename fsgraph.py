#!/usr/bin/env python
"""fsgraph - filesystreem tree to DOT graph

2010-11-28 
	Preliminary version
2011-05-15
	Fixed bugs and issues with symbolic links.
"""
from fnmatch import fnmatch
from itertools import chain
import os
from os import readlink
from os.path import dirname, exists, join, normpath, isdir, islink, isfile, basename, islink
import optparse
import sys




dirs, files, links = {},{},{}
_d, _f, _l = 0,0,0
def dirnid(path):
	global _d
	if os.path.exists(path):
		path = os.path.realpath(path)
	if path not in dirs:
		_d += 1
		dirs[path] = 'd'+str(_d)
	return dirs[path]
def filenid(path):
	global _f
	path = os.path.realpath(path)
	if path not in files:
		_f += 1
		files[path] = 'f'+str(_f)
	return files[path]
def linknid(path):
	global _l
	if path not in links:
		_l += 1
		links[path] = 'l'+str(_l)
	return links[path]

def shortnid(path):
	parts = path.split(os.sep)
	nparts = [p[0] for p in parts if p]

	if path.startswith(os.sep):
		return os.sep + os.sep.join(nparts)
	else:
		return os.sep.join(nparts)

def err(v, *args):
	if args:
		v = v % args
	print >> sys.stderr, v

def print_tree(opts, path):
	print "digraph 123 {"
	print 'rankdir=LR'
	fshier = []
	slinks = []
	brokenlinks = []
	nids = {}
	for root, dirs, files in os.walk(path):
		rootnid = dirnid(root)
		for fn in chain(dirs, files):
			subpath = join(root, fn)
			if [p for p in opts.exclude if fnmatch(subpath, p)]:
				continue
			if islink(subpath):
				nid = linknid(subpath)
				target = readlink(subpath)
				if not target.startswith(os.sep):
					target = os.path.join(dirname(subpath), target)
				targetnid = None
				if islink(target):
					print nid+"[shape=plaintext,color=coral,style=bold,label=\"%s\"]" % basename(subpath)
					targetnid = linknid(target)
					print targetnid+"[shape=plaintext,color=coral,label=\"%s\"]" % target
					slinks.append((nid, targetnid))
				elif isdir(target):
					print nid+"[shape=folder,color=coral,style=bold,label=\"%s\"]" % basename(subpath)
					targetnid = dirnid(target)
					print targetnid+"[shape=folder,color=cornflowerblue,label=\"%s\"]" % target
					slinks.append((nid, targetnid))
				elif isfile(target):					
					print nid+"[shape=note,color=coral,style=bold,label=\"%s\"]" % basename(subpath)
					targetnid = filenid(target)
					print targetnid+"[shape=note,color=darkolivegreen,label=\"%s\"]" % target
					slinks.append((nid, targetnid))
				else:
					err("unknown path: %s", target)
					targetnid = dirnid(target)
					print nid+"[color=coral,label=\"%s\"]" % basename(subpath)
					print targetnid+"[color=red,label=\"%s\"]" % target
					brokenlinks.append((nid, targetnid))
			elif isdir(subpath):
				nid = dirnid(subpath)
				print nid+"[shape=folder,color=cornflowerblue,style=bold,label=\"%s\"]" % basename(subpath)
			elif isfile(subpath):
				nid = filenid(subpath)
				print nid+"[shape=note,color=darkolivegreen,label=\"%s\"]" % basename(subpath)
			else:
				assert False
			nids[subpath] = nid
			fshier.append((rootnid, nid))

	print "edge[color=cornflowerblue]"
	for p, s in fshier:
		print "%s -> %s" % (p, s)

	print "edge[color=coral]"
	for p, s in slinks:
		print "%s -> %s" % (p, s)

	print "edge[color=red]"
	for p, s in brokenlinks:
		print "%s -> %s" % (p, s)

	print "}"


### CLI
usage_descr = "%prog [options] paths"

long_descr = __doc__

argv_descr = (
	('--exclude', {'action': 'append','default':[]}),
	('--exclude-dir', {'action': 'append','default':[]}),
)

def main():
	root = os.getcwd()

	prsr = optparse.OptionParser(usage=usage_descr)
	for a,k in argv_descr:
		prsr.add_option(a, **k)
	opts, args = prsr.parse_args()
	## XXX: more default excludes
	for d in ('bzr', 'svn', 'git', 'build'):
		if not '.'+d in opts.exclude_dir:
			opts.exclude_dir.append('.'+d)
	for ext in ('.part','.swp','~','.swo','.pyc'):
		if not '*'+ext in opts.exclude:
			opts.exclude.append('*'+ext)
	# XXX: ugh!
	opts.exclude += ["%s" % d for d in opts.exclude_dir]
	opts.exclude += [".%s" % d for d in opts.exclude_dir]
	opts.exclude += ["*/%s" % d for d in opts.exclude_dir]
	opts.exclude += ["*/.%s" % d for d in opts.exclude_dir]
	opts.exclude += ["*/%s/*" % d for d in opts.exclude_dir]
	opts.exclude += ["*/.%s/*" % d for d in opts.exclude_dir]
	if not args:
		prsr.error("Need one path argument.")
	path = args.pop()
	if not exists(path):
		prsr.error("Need one existing path (%s)" % path)

	print_tree(opts, path)

def _main():
	try:
		main()
	except KeyboardInterrupt, e:
		print >>sys.stderr, "User interrupt"

if __name__ == '__main__':
	_main()

