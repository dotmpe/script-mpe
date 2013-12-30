from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship, backref

import core
import semweb


class Comment(semweb.Description):

    """
    Comments can be associated with any node.

    Use AnnotatedNode if you need a base type that includes annotation.
    """

    __tablename__ = 'comments'
    __mapper_args__ = {'polymorphic_identity': 'fragment:comment'}

    comment_id = Column('id', Integer, ForeignKey('frags.id'), primary_key=True)

    annotated_node = Column(Integer, ForeignKey('nodes.id'))
    node = relationship(core.Node, 
            primaryjoin=annotated_node==core.Node.node_id)
    comment = Column(Text)



