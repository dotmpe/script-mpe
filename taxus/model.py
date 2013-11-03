

import os
from datetime import datetime
import re
import socket
import stat
import sys

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
	ForeignKey, Table, Index, DateTime
#from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref

#from debug import PrintedRecordMixin 

import iface
from util import SessionMixin

import lib
import log


class LocalResource(Node):

	"""
	Like cached content, identifies a locally served resource.
	"""

	__tablename__ = 'lres'
	__mapper_args__ = {'polymorphic_identity': 'local-resource'}

	lres_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

	host_id = Column(Integer, ForeignKey('hosts.id'))
	host = relationship(Host, primaryjoin=Host.host_id==host_id)
	#resource = ...
	#locator_id = Column(ForeignKey('ids_lctr.id'), index=True)
	#location = relationship(Locator, primaryjoin=locator_id == Locator.id)
	#filesystem_id = Column(Integer, ForeignKey('nodes.id'))
	inode = relationship('INode', primaryjoin='inodes.id == id')



class QName():
	pass#ns = ...



class Namespace(Variant):
	"""
	"""
	__tablename__ = 'ns'
	__mapper_args__ = {'polymorphic_identity': 'resource:variant:namespace'}

	namespace_id = Column('id', Integer, ForeignKey('vres.id'), primary_key=True)


#class BoundNamespace(ID):
#	__tablename__ = 'ns_bid'
#	__mapper_args__ = {'polymorphic_identity': 'id:namespace'}
#
#	prefix = Column(String(255), unique=True)


class Relocated(Resource):

	__tablename__ = 'relocated'
	__mapper_args__ = {'polymorphic_identity': 'resource:relocated'}

	relocated_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

	refnew_id = Column(ForeignKey('ids_lctr.id'), index=True)
	redirect = relationship(Locator, primaryjoin=refnew_id == Locator.lctr_id)

	temporary = Column(Boolean)


class Volume(Resource):

	# XXX: merge with res.Volume

	"""
	A particular storage of serialized entities, 
	as in a local filesystem tree or a blob store.
	"""

	__tablename__ = 'volumes'
	__mapper_args__ = {'polymorphic_identity': 'resource:volume'}

	volume_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

	#type_id = Column(Integer, ForeignKey('classes.id'))
	#store = relation(StorageClass, primaryjoin=type_id==StorageClass.id)

	node_id = Column(Integer, ForeignKey('nodes.id'))
	root = relationship(Node, backref='volumes',
			primaryjoin=node_id == Node.node_id)
	

class Bookmark(Resource):

	"""
	A simple textual annotation with a sequence of tags,
	and is itself a resource.
	"""

	__tablename__ = 'bm'
#	__table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
	__mapper_args__ = {'polymorphic_identity': 'resource:bookmark'}

	bookmark_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

	ref_id = Column(Integer, ForeignKey('ids_lctr.id'))
	ref = relationship(Locator, primaryjoin=Locator.lctr_id==ref_id)

	extended = Column(Text(65535))#, index=True)
	"Textual annotation of the referenced resource. "
	public = Column(Boolean(), index=True)
	"Private or public. "
	tags = Column(String(255))
	"Comma-separated list of tags. "


workset_locator_table = Table('workset_locator', SqlBase.metadata,
	Column('left_id', Integer, ForeignKey('ws.id'), primary_key=True),
	Column('right_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True),
#	mysql_engine='InnoDB', 
#	mysql_charset='utf8'
)


class Workset(Resource):

	"""
	One or more locators together form a new resource that should represent
	the merged subtrees.
	"""

	__tablename__ = 'ws'
#	__table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
	__mapper_args__ = {'polymorphic_identity': 'resource:workset'}

	ws_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

	refs = relationship(Locator, secondary=workset_locator_table)


token_locator_table = Table('token_locator', SqlBase.metadata,
	Column('left_id', Integer, ForeignKey('stk.id'), primary_key=True),
	Column('right_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True),
#	mysql_engine='InnoDB', 
#	mysql_charset='utf8'
)


class Token(SqlBase, SessionMixin):

	__tablename__ = 'stk'
#	__table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
#	__mapper_args__ = {'polymorphic_identity': 'meta:security-token'}

	token_id = Column('id', Integer, primary_key=True)
	#token_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

	value = Column(Text(65535))#, index=True, nullable=True)
	refs = relationship(Locator, secondary=token_locator_table)


