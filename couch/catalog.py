from couchdb.mapping import Document, TextField, IntegerField, DateTimeField, \
    BooleanField, ListField, DictField, Mapping, ViewField


class Catalogdoc(Document):

    entries = ListField(DictField(Mapping.build(
            name = TextField(),
            path = TextField(),
            description = TextField(),

            first_seen = DateTimeField(),
            #first_seen_local = DateTimeField(),
            #date_added = DateTimeField(),
            #last_access = DateTimeField(),
            #date_updated = DateTimeField(),
            #last_modified = DateTimeField(),
            #date_deleted = DateTimeField(),
            deleted = BooleanField(),
            exists = BooleanField(),

            format = TextField(),
            mediatype = TextField(),
            size = TextField(),
            tags = ListField(TextField()),
            keys = DictField()
        )))

    by_name = ViewField('catalog', '''\
        function(doc) {
            emit(doc.name, doc);
        }''')

    def __init__(self, *args, **kwds):
        super(Catalogdoc, self).__init__(*args, **kwds)
