from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship, backref

from . import core


class Description(core.Node):

    """
    A scheme+localname.
    """

    __tablename__ = 'frags'
    __mapper_args__ = {'polymorphic_identity': 'fragment'}

    fragment_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

# XXX to clean
#    namespace_id = Column(Integer, ForeignKey('ns.id'))
#    namespace = relationship('Namespace', 
#            primaryjoin='namespace_id==Namespace.namespace_id')

#    variants = relationship('Variant', backref='descriptions',
#            secondary=fragment_variant_table)

#= Table('resource_variant', SqlBase.metadata,
#    Column('res_ida', Integer, ForeignKey('res.id'), primary_key=True),
#    Column('vres_idb', Integer, ForeignKey('vres.id'), primary_key=True),
##    mysql_engine='InnoDB', 
##    mysql_charset='utf8'
#)


# XXX unused cwm-like stuff
class Predicate: pass
class SeeAlso(Predicate): pass
class SameAs(Predicate): pass
class AlternativeLink(Predicate): pass
class StylesheetLink(Predicate): pass
class Statement:
    predicate, subject, object = 'p','x','y'
class Formula:
    statements = ()
#


models = [ Description ]

