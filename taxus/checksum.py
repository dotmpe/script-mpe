from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship, backref

from .init import SqlBase
from .util import ORMMixin

from script_mpe import lib
from . import core
from . import fs


class ChecksumDigest(SqlBase, ORMMixin):

    """
    Superclass for fixed length content checksums
    and other lossy content digests.
    """
    __tablename__ = 'chks'

    chk_id = Column('id', Integer, primary_key=True)

    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)

    digest_type = Column('digest_type', String(50))
    __mapper_args__ = {'polymorphic_on': digest_type}

    def __str__(self):
        return "%s:%s" % (self.digest_type.lower(), self.digest)

    def __repr__(self):
        return "<%s for %s>" % (lib.cn(self), self.digest)

class SHA1Digest(ChecksumDigest):
    """
    A 160bit digest.
    """
    __tablename__ = 'chks_sha1'
    sha1_id = Column('id', Integer, ForeignKey('chks.id'), primary_key=True)
    __mapper_args__ = {'polymorphic_identity': 'SHA1'}
    digest = Column(String(40), index=True, unique=True, nullable=False)


class MD5Digest(ChecksumDigest):
    """
    A 128 bit digest.
    """
    __tablename__ = 'chks_md5'
    md5_id = Column('id', Integer, ForeignKey('chks.id'), primary_key=True)
    __mapper_args__ = {'polymorphic_identity': 'MD5'}
    digest = Column(String(32), index=True, unique=True, nullable=False)


#class TTHDigest(ChecksumDigest):
#    """
#    ???
#    """
#    tth_id = Column('id', Integer, ForeignKey('chks.id'), primary_key=True)
#    __mapper_args__ = {'polymorphic_identity': 'TTH'}
#    block_size = Column(Integer, default=1024)
#    digest = Column(String(32), index=True, unique=True, nullable=False)

#inode_checksum_table = Table('inode_checksum', SqlBase.metadata,
#    Column('inode_id', Integer, ForeignKey('inodes.id'), primary_key=True),
#    Column('chk_id', Integer, ForeignKey('chks.id'), primary_key=True),
#)
#
#fs.INode.checksums = relationship(ChecksumDigest, secondary=inode_checksum_table)


models = [ ChecksumDigest, SHA1Digest, MD5Digest ]
