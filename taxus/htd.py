from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime

from . import core


class TNode(core.Document):

    """
    A (structured) text node. The name is set to a named prefix, and a local ref.

    Name equals <context> ':' <local-path-name>

    Map to inode by resolving the ntype for <context>, and translating the ref.
    """
    __tablename__ = 'tnodes'
    __mapper_args__ = {'polymorphic_identity': 'doc:t'}

    doc_id = Column('id', Integer, ForeignKey('docs.id'), primary_key=True)

    # tags
    # topics


class JournalEntry(TNode):
    pass


