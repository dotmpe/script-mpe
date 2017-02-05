#!/usr/bin/env python
"""Relink symbolic links using regular expressions.
"""
import os
import sys
import re

usage = """Relink, rename the targets of symbolic links using regular
expressions.

Usage: % relink [options] match replace [- | links...]

Options:
    -n  
        No-act, only print the shell equivalent of the link command that would be 
        performed
    -v
        Verbose.
    --shell-commands  
        Same as no-act, but also print the shell equivalent of the unlink command 
        that is normally performed.        

"""
def relink(link, target, ntarget):
    global verbose

    if verbose:
        print "Relinking <%s> (%s)" % (link, target)

    linkdir = os.path.dirname(link)
    if linkdir and linkdir != os.getcwd():
        try:
            if linkdir != os.getcwd():
                if noact_pr_shell:
                    print 'cd "%s"' % linkdir
                os.chdir(linkdir)
        except IOError, e:
            print >>sys.stderr, "Unable to change to directory for link <%s>, skipping rename..." % link
            return

    linkname = os.path.basename(link)
    if noact:
        if noact_pr_shell:
            print 'rm "%s"' % linkname
            print 'ln -s "%s" "%s"' % (ntarget, linkname)
        else:
            print "Rewrite target <%s> to <%s>" % (target, ntarget)
    else:
        try:
            os.unlink(linkname)
        except IOError, e:    
            print >>sys.stderr, "Unable to unlink <%s>, skipping rename..." % link
            return
        try:
            os.symlink(ntarget, linkname)
        except IOError, e:    
            print >>sys.stderr, "Link <%s> to renamed target <%s> failed!\n!!! Lost link <%s> (%s)" % (link, ntarget, link, target)
            return


seps = ' \n\r\0\t'
noact, noact_pr_shell = False, False
if not len(sys.argv)>3 or '-h' in sys.argv or '-?' in sys.argv or '--help' in sys.argv:
    sys.exit(usage)

opts = 0
if '-n' in sys.argv:
    noact = True # dry run
    opts += 1
if '--shell-commands' in sys.argv:
    noact = True
    noact_pr_shell = True # dry run, print shell command
    opts += 1

verbose = False
if '-v' in sys.argv:
    verbose = True
    opts += 1

if sys.argv[-1] == '-':
    links = sys.stdin.readlines()#.split(seps)
else:
    links = sys.argv[opts+3:]
find, replace = sys.argv[opts+1:opts+3]

find = re.compile(find)

pwd = os.getcwd()
if verbose:
    print "# In directory %s" % pwd

# parse links, 1st pass    
_links = []    
for link in links:
    link = link.strip(seps)
    if not link or not os.path.islink(link):    
        continue

    link = os.path.abspath(link)    
    linkdir = os.path.dirname(link)
    os.chdir(linkdir)
    target = os.path.abspath(os.readlink(link))
    _links.append((link, target))
    os.chdir(pwd)
links = _links

# rename links, 2nd pass
for link, target in links:
    if find.match(target):

        ntarget = find.sub(replace, target)
        relink(link, target, ntarget)

    elif find.search(target):
        m = find.search(target)
        if len(m.groups()) > 1:
            print >>sys.stderr, "Search pattern should match either single group or entire target path. "
            continue

        ntarget = find.sub(replace, target, count=1)
        relink(link, target, ntarget)

    elif verbose:
        print >>sys.stderr, 'Unmatched link target for <%s>, target was <%s>' % (link, target)

if pwd and pwd != os.getcwd():
    if noact_pr_shell:
        print 'cd ', pwd 
    os.chdir(pwd)





