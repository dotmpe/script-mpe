from sqlalchemy import Column, Integer, String, Boolean, Text, \
	ForeignKey, Table, Index, DateTime

from init import SqlBase
from util import SessionMixin

import core


class ChecksumDigest(SqlBase, SessionMixin):

	"""
	Superclass for fixed length content checksums
	and other lossy content digests.
	"""
	__tablename__ = 'ids_chks'

	chks_id = Column('id', Integer, primary_key=True)

	date_added = Column(DateTime, index=True, nullable=False)
	deleted = Column(Boolean, index=True, default=False)
	date_deleted = Column(DateTime)

	digest_type = Column('digest_type', String(50))
	__mapper_args__ = {'polymorphic_on': digest_type}


class SHA1Digest(ChecksumDigest):
	"""
	A 160bit digest.
	"""
	__tablename__ = 'ids_chks_sha1'
	sha1_id = Column('id', Integer, ForeignKey('ids_chks.id'), primary_key=True)
	__mapper_args__ = {'polymorphic_identity': 'SHA1'}
	digest = Column(String(40), index=True, unique=True, nullable=False)


class MD5Digest(ChecksumDigest):
	"""
	A 128 bit digest.
	"""
	__tablename__ = 'ids_chks_md5'
	md5_id = Column('id', Integer, ForeignKey('ids_chks.id'), primary_key=True)
	__mapper_args__ = {'polymorphic_identity': 'MD5'}
	digest = Column(String(32), index=True, unique=True, nullable=False)


#class TTHDigest(ChecksumDigest):
#	"""
#	???
#	"""
#	tth_id = Column('id', Integer, ForeignKey('chks.id'), primary_key=True)
#	__mapper_args__ = {'polymorphic_identity': 'TTH'}
#	block_size = Column(Integer, default=1024)
#	digest = Column(String(32), index=True, unique=True, nullable=False)



