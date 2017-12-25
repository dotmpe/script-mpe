import zope.interface

from couchdb.mapping import Document, TextField, IntegerField, DateTimeField, \
    BooleanField, ListField, DictField

from script_mpe.taxus import iface


# NOTE: annotating CouchDB's document is no use, need to call after Class.load
zope.interface.classImplements(Document, iface.IPyDict)

class Bookmark(Document):
    zope.interface.implements(iface.IPyDict)

    date_added = DateTimeField()
    date_deleted = DateTimeField()
    date_updated = DateTimeField()
    deleted = BooleanField()

    href = TextField()
    last_access = DateTimeField()
    last_modified = DateTimeField()
    last_update = DateTimeField()

    name = TextField()
    extended = TextField()
    public = BooleanField()
    status = IntegerField()
    tags = ListField(TextField())
    #tags = TextField()
    tag_list = ListField(TextField())
    type = TextField()

zope.interface.classImplements(Bookmark, iface.IPyDict)
