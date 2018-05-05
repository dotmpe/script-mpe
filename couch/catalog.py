from couchdb.mapping import Document, TextField, IntegerField, DateTimeField, \
    BooleanField, ListField, DictField, Mapping, ViewField

from script_mpe.taxus import iface


class Catalogdoc(Document):

    entries = ListField(DictField(Mapping.build(

            name = TextField(),
            path = TextField(),

            description = TextField(),

            date_added = DateTimeField(),
            last_access = DateTimeField(),
            date_updated = DateTimeField(),
            last_modified = DateTimeField(),
            date_deleted = DateTimeField(),
            deleted = BooleanField(),

            file_type = TextField(),
            file_size = TextField(),
            tags = ListField(TextField()),
            keys = DictField()
        )))

    by_name = ViewField('catalog', '''\
        function(doc) {
            emit(doc.name, doc);
        }''')

    def __init__(self, *args, **kwds):
        super(Catalogdoc, self).__init__(*args, **kwds)
        # TODO: can we init for Catalogdoc.load here?
        self.keys = {}

    def init(self):
        for i, it in enumerate(self.entries):
            assert it not in self.keys, it
            self.keys[it.name] = i

    def __contains__(self, name):
        if name in self.keys:
            return True
        #return super(Catalogdoc, self).__contains__(name)
