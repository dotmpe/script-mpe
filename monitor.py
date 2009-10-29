#!/usr/bin/env python
"""
Report updated and modified files in monitored trees.
"""
import os, re, optparse, confparse, itertools


config = confparse.get_config('monitor')
settings = confparse.ini(config)

# Predefined values, override in config file
monitors = settings.monitors.getlist([ '~/htdocs/' ])

# Hard coded
usage_descr = """%monitor [options] paths"""

options_spec = (
    ('--add-monitor', {'default': None, 'help': "." }),
)


def getpath(name, *dirs):
    paths = []
    j = os.path.join
    [ paths.extend([ j(d, name), j(d, '.' + name) ]) for d in dirs ]
    for p in paths:
    	yield p

def getconfig(name, all=False, force=False):
	"""Return path to existing config file.
	Set all to return every existing path, not just the first.
	Set force to touch a non-existing path, either the first (all=False) or 
	the last (all=True).
	"""
	for path in itertools.chain(
			getpath(name +'.conf', '', '~', '/etc/'),
			getpath('main.conf', '/etc/' + name)):
		if os.path.exists(path):
			yield path
			if not all: break
		elif force and not all:
			break

	if force:
		mkdirs(os.path.dirname(path))
		os.mknod(path)
		yield path				


def main():
    root = os.getcwd()

    prsr = optparse.OptionParser(usage=usage_descr)
    for a,k in options_spec:
        prsr.add_option(a, **k)
    opts, args = prsr.parse_args()

    for path in args:
        print list(getconfig('monitor'))


if __name__ == '__main__':
    main()
