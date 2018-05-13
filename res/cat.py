"""Py lib for catalog routines"
"""
import os
import ruamel.yaml as yaml

from .. import libfile


class Catalog:

    def __init__(self, fn):
        self.name = fn
        self.data = yaml.safe_load(open(fn))
        self.names = {}
        for i, r in enumerate(self.data):
            self.names[r['name']] = i

    def add_file(self, fname, opts):
        assert fname not in self.names
        self.data.append({
                "name": os.path.basename(fname),
                "mediatype": libfile.filemtype(fname),
                "format": libfile.file_brief_description(fname),
                "keys": {}
            })

    def write(self, opts, fn=None):
        if not fn: fn=self.name
        fl = open(fn, 'w+')
        yaml_writer(opts.catalog.data, fl, confparse.Values(dict(
            opts=opts )))
