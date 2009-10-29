#!/usr/bin/env python
"""
Catalog provided paths. Catalog entries can be referenced by volume, 
content-hash. Content may be redundantly stored across multiple volumes.

Each storage location has a unique identifier and may (temporarily) hold 
resources. It has a fixed size.
"""
import os, re, confparse, optparse


config = confparse.get_config('volume')
settings = confparse.ini(config)

catalog_root = settings.catalog.root.getstr('~/htdocs/catalog')
archive_sep = ''
archive_format = "%(year)s/%(month)s/%(day)s"

usage_descr = """%archive [options] paths"""

options_spec = (
    ('--archive-root', {'default': archive_root, 'help':
        "The directory in which the ``archive-format`` is based in. " }),
)


class Volume(object):
	pass

class Catalog(object):

	def __init__(self, root, **settings):
		pass


def main():
    root = os.getcwd()
    cat = Catalog(root)

    prsr = optparse.OptionParser(usage=usage_descr)
    for a,k in options_spec:
        prsr.add_option(*a, **k)
    opts, args = prsr.parse_args(sys.argv)

    args.pop(0)

	

if __name__ == '__main__':
    main()

