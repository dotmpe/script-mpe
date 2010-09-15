#!/usr/bin/env python
"""
:author: B. van Berkum  <dev@dotmpe.com>
:created: 2010-09-07

Duplicate given paths from src directory into trgt directory.
"""
import sys, os, shutil


read = False
delete_src = False
verbose = True
noact = False

args = sys.argv[1:]

if '-' in args:
     args.remove('-')
     read = True
if '-n' in args:
    args.remove('-n')
    noact = True

if args:
    srcroot = os.path.abspath(args.pop(0))
else:
    srcroot = os.path.abspath('.')

trgtroot = os.path.abspath(args.pop())


assert not args, "Usage: mirror [src-root-dir=.] trgt-root-dir"

if verbose:
    print "Mirror: replicating from <%s> to <%s>" % (srcroot, trgtroot)

if read:
    if verbose:
        print "Mirror: Reading from stdin"
    paths = [ p.strip() for p in sys.stdin.readlines() ]
    count = len(paths)
else:
    if verbose:
        print "Mirror: Traversing %s" % srcroot
    paths = []
    count = 0
    for root, dirs, files in os.walk(srcroot):
        paths += [ os.path.join(srcroot, root, dn) for dn in dirs ]\
                + [ os.path.join(srcroot, root, fn) for fn in files ]
        count += len(files)+len(dirs)

print >>sys.stderr, "Mirror: %s %s nodes" % (['copying','moving'][int(delete_src)], count)

for path in paths:
    if not os.path.exists(path) or not path.startswith(srcroot):
        path = os.path.join(srcroot, path)
    if not os.path.exists(path):
        print >>sys.stderr, "No such file %s" % (os.path.join('.', path))
        continue
    trgt = os.path.join(trgtroot, path[len(srcroot):].strip(os.sep))
    if os.path.exists(trgt):
        if not os.path.isdir(src):
            print >>sys.stderr, "Mirror: fail, target %s exists" % trgt
        continue            
    if verbose:
        print "<%s> to <%s>" % (path, trgt)
    if noact:
        continue
    if delete_src:
        os.renames(path, trgt)
    else:        
        if os.path.isdir(path):
            os.makedirs(trgt)
        else:
            if not os.path.exists(os.path.dirname(trgt)):
                os.makedirs(os.path.dirname(trgt))
            shutil.copy2(path, trgt)

