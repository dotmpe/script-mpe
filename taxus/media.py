import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref

from . import core
from . import init
from . import checksum



class Mediatype(core.Name):

    """
    Categorizes the transport and or storage format of a datastream.
    MIME classes all types in several major types, with numerous minor types.
    """

    __tablename__ = 'mediatypes'
    __mapper_args__ = {'polymorphic_identity': 'mediatype'}

    mt_id = Column('id', ForeignKey('names.id'), primary_key=True)


class MediatypeParameter(core.Name):

    """
    A media type may be parameterized by charset, encodings or formatting.
    """

    __tablename__ = 'mediatype-parameters'
    __mapper_args__ = {'polymorphic_identity': 'mediatype-parameter'}

    mtp_id = Column('id', ForeignKey('names.id'), primary_key=True)



class Genre(core.Name):

    __tablename__ = 'genres'
    __mapper_args__ = {'polymorphic_identity': 'genre'}

    genre_id = Column('id', ForeignKey('names.id'), primary_key=True)


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
    Basic metadata card
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

    # TODO: paramaters
    #mediaformat_id = Column(Integer, ForeignKey('mediaformats.id'))
    #mediaformat = relationship(Mediaformat,
    #        primaryjoin=mediaformat_id==Mediaformat.mf_id)

    #genres = relationship(Genre, secondary=mediameta_genre_table)


models = [ Mediatype, MediatypeParameter, Genre, Mediameta ]
