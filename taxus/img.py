from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, select, func
from sqlalchemy.orm import relationship

from . import core
from .mixin import CardMixin
from .init import SqlBase
from .util import ORMMixin


"""
photo_topic = Table('topic_photo', SqlBase.metadata,
        Column('id', Integer, primary_key=True),
        Column('photo_id', ForeignKey('photos.id'), primary_key=True),
        Column('topic_id', ForeignKey('names_topic.id'), primary_key=True)
    )

photo_tag = Table('photo_tag', SqlBase.metadata,
        Column('id', Integer, primary_key=True),
        Column('photo_id', ForeignKey('names_photo.id'), primary_key=True),
        Column('tag_id', ForeignKey('names_tag.id'), primary_key=True)
    )

"""
class Photo(SqlBase, CardMixin, ORMMixin):

    __tablename__ = 'photos'

    photo_id = Column('id', String, primary_key=True)

"""
    topic = relationship(core.Topic, secondary=photo_topic, backref='photos')
    tags = relationship(core.Tag, secondary=photo_tag, backref='photos')


"""
models = [ Photo ]
