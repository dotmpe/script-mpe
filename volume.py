#!/usr/bin/env python
"""
Catalog provided paths. Catalog entries can be referenced by path relative to
volume or rather by content-hash. 
Content may be redundantly stored across multiple volumes.

Each storage location has a unique identifier and may (temporarily) hold 
resources. It has a fixed size.
"""
import os, re 

import confparse
import taxus
from taxus import Taxus


#config = confparse.get_config('volume')
#settings = confparse.ini(config)
#
#catalog_root = settings.catalog.root.getstr('~/htdocs/catalog')
#archive_sep = ''
#archive_format = "%(year)s/%(month)s/%(day)s"
#
#usage_descr = """%archive [options] paths"""


class Volume(Taxus):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DEFAULT_CONFIG_KEY = NAME

    TRANSIENT_OPTS = Taxus.TRANSIENT_OPTS + []
    DEFAULT_ACTION = ''
    
    def get_opts(self):
        return Cmd.get_opts(self) + (
#            (('--archive-root',), {'default': archive_root, 'help':
#                "The directory in which the ``archive-format`` is based in. " }),
            )

    subcmd_aliases = {
            'rm': 'remove',
            'upd': 'update',
            'ad': 'add',
        }

    def volume(self, args, opts):
        subcmd = args[0]
        while subcmd in subcmd_aliases:
            subcmd = subcmd_aliases[subcmd]
        assert subcmd in ('add', 'update', 'remove'), subcmd
        node = getattr(self, "volume_"+subcmd)(args[1:], opts)
        #interface = interfaces.CLInterface
        #adapt(node, interface)

    def volume_add(self, args, opts):
        s = get_session(opts.get('dbref'))
        
        if args:
            opts.name = args.pop(0)
        assert opts.name, opts.name
        if args:
            opts.ref = 
        assert opts.ref, opts.ref

        l = self.locator_find(opts.ref)
        node = Volume(name="",
                locator=l,
                date_added=datetime.now())
        if l.inode.exists():
            node.last_seen = datetime.now()

        return node

    def volume_remove(self, **opts):
        s = get_session(opts.get('dbref'))



if __name__ == '__main__':
    Volume().main()

