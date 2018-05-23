"""Py lib for catalog routines"
"""
import os
import ruamel.yaml as yaml

from .. import libfile, confparse
from ..jsotk_lib import yaml_writer


class Catalog:

    def __init__(self, fn):
        self.name = fn
        self.data = yaml.safe_load(open(fn))
        if not self.data:
            self.data = []
        self.names = {}
        for i, r in enumerate(self.data):
            self.names[r['name']] = i

    def add_name(self, fname, opts):
        name = os.path.basename(fname)
        assert name not in self.names
        d = {
                "name": name,
                "exists": False,
                "keys": {}
            }
        if '/' in fname:
            d["categories"] = list(os.path.dirname(fname))
        self.data.append(d)

    def add_file(self, fname, opts):
        name = os.path.basename(fname)
        assert name not in self.names
        rname = os.path.realpath(fname)
        d = {
                "name": name,
                "mediatype": libfile.filemtype(rname),
                "format": libfile.file_brief_description(rname),
                "keys": {}
            }
        if '/' in fname:
            d["categories"] = list(os.path.dirname(fname))
        self.data.append(d)

    def write(self, opts, fn=None):
        if not fn: fn=self.name
        fl = open(fn, 'w+')
        yaml_writer(opts.catalog.data, fl, confparse.Values(dict(
            opts=opts )))
