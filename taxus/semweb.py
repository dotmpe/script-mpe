import core


class Description(core.Node):

    """
    A scheme+localname.
    """

    __tablename__ = 'frags'
    __mapper_args__ = {'polymorphic_identity': 'fragment'}

    fragment_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

#    namespace_id = Column(Integer, ForeignKey('ns.id'))
#    namespace = relationship('Namespace', 
#            primaryjoin='namespace_id==Namespace.namespace_id')

    variants = relationship('Variant', backref='descriptions',
            secondary=fragment_variant_table)


# XXX
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


