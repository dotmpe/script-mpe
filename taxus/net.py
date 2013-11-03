import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
	ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship, backref

from init import SqlBase
from util import SessionMixin
import core
import util
import iface
import checksum


class Host(core.Node):
	"""
	"""
	__tablename__ = 'hosts'
	__mapper_args__ = {'polymorphic_identity': 'host'}

	host_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)
	hostname_id = Column(Integer, ForeignKey('ids_name.id'))
	hostname = relationship(core.Name, primaryjoin='Host.hostname_id==Name.name_id')

	@classmethod
	def current(klass, session):
		hostname_ = current_hostname()
		hostname = session.query(Name)\
			.filter(Name.name == hostname_).one()
		return session.query(klass).filter(Host.hostname == hostname).one()

	@property
	def netpath(self):
		return "//%s" % self.hostname.name

	def __str__(self):
		return "<Host %s>" % self.hostname

	def __repr__(self):
		return "<Host %r>" % self.hostname

# mapping table for Host [1-1] Locator
#locator_host = Table('locator_host', SqlBase.metadata,
#	Column('locator_ida', ForeignKey('ids_lctr.id')),
#	Column('host_idb', ForeignKey('hosts.id'))
#)
# mapping table for ChecksumDigest [1-*] Locator
locators_checksum = Table('locators_checksum', SqlBase.metadata,
	Column('locators_ida', ForeignKey('ids_lctr.id')),
	Column('chk_idb', ForeignKey('ids_chks.id'))
)
# mapping table for Tag [*-*] Locator
locators_tags = Table('locators_tags', SqlBase.metadata,
	Column('locator_ida', ForeignKey('ids_lctr.id')),
	Column('tags_idb', ForeignKey('ids_tag.id'))
)

class Locator(SqlBase, SessionMixin):

	"""
	A global identifier for retrieval of remote content.
	"""
	zope.interface.implements(iface.IID)

	__tablename__ = 'ids_lctr'
	lctr_id = Column('id', Integer, primary_key=True)

	date_added = Column(DateTime, index=True, nullable=False)
	deleted = Column(Boolean, index=True, default=False)
	date_deleted = Column(DateTime)

	#ref = Column(String(255), index=True, unique=True)
	# XXX: varchar(255) would be much too small for many URL locators 
	ref = Column(Text(2048), index=True, unique=True)

	@property
	def scheme(self):
		ref = self.ref
		if re.match(r'^[a-z][a-z0-1-]+:.*$', ref):
			return ref.split(':')[0]

	@property
	def path(self):
		ref = self.ref
		scheme = self.scheme
		if scheme: # remove scheme
			assert ref.startswith(scheme+':'), ref
			ref = ref[len(scheme)+1:]
		# FIXME:
		if self.host:
			if ref.startswith("//"): # remove netpath 
				ref = ref[2+len(self.host):]
			return ref
		else:
			assert ref.startswith('//'), ref
			ref = ref[2:]
			p = ref.find('/')
			if p != -1: # split of host
				return ref[p:]
			else:
				assert not "No path", ref

	checksum = relationship('ChecksumDigest', secondary=locators_checksum,
		backref='locations')
	tags = relationship('Tag', secondary=locators_tags,
		backref='locations')
	host_id = Column(Integer, ForeignKey('hosts.id'))
	host = relationship('Host', primaryjoin="Locator.host_id==Host.host_id",
		backref='locations')

	def __str__(self):
		return "<%s %r>" % (lib.cn(self), self.ref)



