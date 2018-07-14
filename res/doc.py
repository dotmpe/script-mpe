class Catalog(object):
    def __init__(self):
        super(Catalog, self).__init__()
        self._entries = 0
        self.keys = {}

    @classmethod
    def load(klass, ctx, name='catalog'):
        self = klass()
        self.entries = ctx.ws.yamldoc(name, defaults=[])
        # TODO adapt Workspace.yamldoc and couchb.mapping.Document?
        #docid = ctx.ws.full_path + '.catalog'
        #if ctx.docs and docid in ctx.docs:
        #    catalog = couch.catalog.Catalogdoc.load(ctx.docs, name)
        #else:
        #    catalog = couch.catalog.Catalogdoc()
        #catalog = couch.catalog.Catalogdoc(keys.. **catalog_dict)

        for it in self.entries:
            self.add_entry(it)
        return self

    def add_entry(self, item, name=None):
        if not name and 'name' not in item and not hasattr(item, 'name'):
            print('No-name', item)
            return
        if not name: name = item['name']
        if not name: name = item.name
        i = ++self._entries
        self.keys[name] = i

    def __contains__(self, name):
        if name in self.keys:
            return True

    def __getitem__(self, name):
        return self.entries[self.keys[name]]

    def __setitem__(self, name, value):
        if name not in self.keys:
            self.add_entry(value, name)
        else:
            self.entries[self.keys[name]] = value
