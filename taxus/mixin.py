from datetime import datetime

from sqlalchemy import Column, Boolean, DateTime, Integer, ForeignKey
from sqlalchemy.orm import relationship, backref
from sqlalchemy.orm.collections import attribute_mapped_collection


class CardMixin(object):

    deleted = Column(Boolean, index=True, default=False)

    date_added = Column(DateTime, index=True, nullable=False)
    date_deleted = Column(DateTime)
    date_updated = Column(DateTime, index=True, nullable=False)

    def delete(self):
        self.deleted = True
        self.date_deleted = datetime.now()

    def init_defaults(self):
        if not self.date_added:
            self.date_updated = self.date_added = datetime.now()
        elif not self.date_updated:
            self.date_updated = datetime.now()

    keys = 'deleted date_added date_deleted date_updated'.split(' ')


def groupnode(klass, up='super', down='sub', name='node',
        keyattr='name', cascade="all, delete-orphan"):


    """
    Add Adjacency list attributes to klass.
    """

    uprel = up+name
    downrel = down+name+'s'
    idrel = up+name+'_id'

    _id = Column(Integer, ForeignKey('%s.id' % klass.__tablename__))
    remote_id = klass.metadata.tables[klass.__tablename__].columns['id']

    setattr(klass, idrel, _id)
    setattr(klass, downrel, relationship(klass,
        cascade=cascade,
        backref=backref(uprel, remote_side=[remote_id]),
        foreign_keys=[_id],
        collection_class=attribute_mapped_collection(keyattr),
    ))

    # Explicit indicator for root nodes, where remote_id is null
    setattr(klass, 'is_root'+name, Column(Boolean))
