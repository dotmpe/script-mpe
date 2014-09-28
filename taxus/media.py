import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref

import core
import init
import checksum


class Mediatype(core.Node):
    
    """
    Categorizes the transport and or storage format of a datastream.
    MIME classes all types in several major types.
    """
    
    __tablename__ = 'mediatypes'
    __mapper_args__ = {'polymorphic_identity': 'mediatype'}

    mt_id = Column('id', ForeignKey('nodes.id'), primary_key=True)

    mime_id = Column(Integer, ForeignKey('names.id'))
    mime = relationship(core.Name, primaryjoin=mime_id==core.Name.name_id)


class Mediaformat(core.Name):

    """
    For many types of media there are variations in format.
    Ie. written media come as books or essays. 
    """
    
    __tablename__ = 'mediaformats'
    __mapper_args__ = {'polymorphic_identity': 'mediaformat'}

    mf_id = Column('id', ForeignKey('names.id'), primary_key=True)


    #container_type_id = Column(Integer, ForeignKey('mediatypes.id'))

#Mediatype.subtypes = relationship(Mediatype, Mediatype.container_type_id==Mediatype.mt_id)

class Genre(core.Node):
    
    __tablename__ = 'genres'
    __mapper_args__ = {'polymorphic_identity': 'genre'}

    genre_id = Column('id', ForeignKey('nodes.id'), primary_key=True)


mediameta_checksum_table = Table('mediameta_checksum', init.SqlBase.metadata,
    Column('mm_id', Integer, ForeignKey('mm.id'), primary_key=True),
    Column('chk_id', Integer, ForeignKey('chks.id'), primary_key=True),
)

mediameta_genre_table = Table('mediameta_genre', init.SqlBase.metadata,
    Column('mm_id', Integer, ForeignKey('mm.id'), primary_key=True),
    Column('genre_id', Integer, ForeignKey('genres.id'), primary_key=True),
)

class Mediameta(core.Node):

    """
    Metadata for certain distributions, releases, episodes, volumes, etc.
    """
    
    __tablename__ = 'mm'
    __mapper_args__ = {'polymorphic_identity': 'mediameta'}

    mm_id = Column('id', ForeignKey('nodes.id'), primary_key=True)

    checksums = relationship(checksum.ChecksumDigest,
            secondary=mediameta_checksum_table)
    "To find the Metadata record given an unknown content stream. "

    mediatype_id = Column(Integer, ForeignKey('mediatypes.id'))
    mediatype = relationship(Mediatype,
            primaryjoin=mediatype_id==Mediatype.mt_id)

    mediaformat_id = Column(Integer, ForeignKey('mediaformats.id'))
    mediaformat = relationship(Mediaformat,
            primaryjoin=mediaformat_id==Mediaformat.mf_id)

    genres = relationship(Genre, secondary=mediameta_genre_table)



models = [ Mediaformat, Mediatype, Genre, Mediameta ]
