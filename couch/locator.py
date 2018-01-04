import zope.interface

from couchdb.mapping import Document, TextField, IntegerField, DateTimeField, \
    BooleanField, ListField, DictField, Mapping

from script_mpe.taxus import iface


class Bookmark2(Document):
    zope.interface.implements(iface.IPyDict)

    type = TextField()
    date_added = DateTimeField()
    date_deleted = DateTimeField()
    date_updated = DateTimeField()
    deleted = BooleanField()

    href = DictField(Mapping.build(

        last_access = DateTimeField(),
        last_modified = DateTimeField(),
        date_updated = DateTimeField(),

        status = IntegerField(),
        net = BooleanField()
    ))

    name = TextField()
    extended = TextField()
    public = BooleanField()
    tags = ListField(TextField())
