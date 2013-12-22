#!/usr/bin/env python
"""
Taxus ORM (SQL) model.

All objects inherit from Node. Each object type is has its own table. Stored
objects have records in `nodes` and all other 'parent' tables (references via
foreign-keys). The `nodes` table stores the objects type, meaning there can be 
only one type for a node record at any time.

TODO: redraw this diagram.
Inheritance hierarchy and relations::

                         Node
                          * id:Integer
                          * ntype:<polymorphic-ID>
                          * name:String(255)
                          * date-added
                          * deleted
                          * date-deleted

                              A
                              |
        .---- .----------- .--^-------. ----------. -----. 
        |     |            |          |            |      |   
        |    Token         |          |            |      |
        |     * value      |          |            |      |
        |     * refs       |          |            |      |
        |                  |          |            |      |
       INode               |         Status       Host    |
        * local_path:255   |          * nr         * hostname 
        * size             |          * http_code         |
        * cum_size         |                              |
        * host:Host        |          ^                   |
                           |          |                   | 
          A                |          |                   | 
          |                |          |                   | 
       CachedContent      Resource    |                   |    
        * cid              * status --/                   |        
        * size             * location:Location            | 
        * charset          * last/a/u-time                |  
        * partial          * allowed                      | 
        * expires                                         |
        * etag             A                              |
        * encodings        |                              |
                           |                              | 
        ^                  |                        /--< Description
        |                  |                        |     * namespace:Namespace
        |  Invariant ------'-- Variant              |      
        \-- * content      |    * vary              |     A               
            * mediatype    |    * descriptions >----/     |         
            * languages    |                              '-- Comment       
                           |    A                         |    * node:Node
                           |    |                         |    * comment:Text
                           |    |                         |     
                           |   Namespace                  '-- ...
                           |    * prefix:String           * subject    
                           |                              * predicate   
                           '-- Relocated                  * object     
                           |    * redirect:Location 
                           |    * temporary:Bool
                           |                                                
                           '-- Bookmark                  Formula         
                                                          * statements
                           '-- Volume
                           '-- Workset

          ChecksumDigest   
           * date_added
           * date_/deleted
           A
           |
     .-----^------.
     |            |
    SHA1Digest   MD5Digest
     * digest     * digest

    ID 
     * id:Integer
     * date-added
     * deleted
     * date-deleted

         A
         |
     .---^------.
     |          |
     |        Name
     |         * id
     |         * name
     |
   Locator   
    * id
    * ref
    * checksums


This schema will make node become large very quickly. Especially as various
metadata relations between Nodes are recorded in Statements.
In addition, Statements will probably rather refer to Fragment nodes rather than 
Resource nodes, adding another layer of similar but distinct nodes.

The Description column in the diagram is there to get an idea, while most such
data should be stored a suitable triple store.

TODO: move all models to _model module.
"""
import sys
import os
from datetime import datetime
import re
import socket

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
	ForeignKey, Table, Index, DateTime, \
	create_engine
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

#from debug import PrintedRecordMixin 

import taxus_out
import lib
import log



SqlBase = declarative_base()
metadata = SqlBase.metadata

class DNSLookupException(Exception):

	def __init__( self, addr, exc ):
		self.addr = addr
		self.exc = exc

	def __str__( self ):
		return "DNS lookup error for %s: %s" % ( self.addr, self.exc )

DNSCache = {}

def nameinfo(addr):
	try:
		DNSCache[ addr ] = socket.getaddrinfo(
			addr[ 0 ], addr[ 1 ], socket.AF_INET, socket.SOCK_STREAM )
	except Exception, e:
		raise DNSLookupException(addr, e)

	print DNSCache[ addr ][ 0 ]

	family, socktype, proto, canonname, sockaddr = DNSCache[ addr ][ 0 ]


# Util classes
class SessionMixin(object):

	sessions = {}

	@staticmethod
	def get_instance(name='default', dbref=None, init=False):
		if name not in SessionMixin.sessions:
			assert dbref, "session does not exists: %s" % name
			session = get_session(dbref, init)
			#assert session.engine, "new session has no engine"
			SessionMixin.sessions[name] = session
		else:
			session = SessionMixin.sessions[name]
			#assert session.engine, "existing session does not have engine"
		return session

	# 
	key_names = ['id']

	def key(self):
		key = {}
		for a in self.key_names:
			key[a] = getattr(self, a)
		return key

	def commit(self):
		session = SessionMixin.get_instance()
		session.add(self)
		session.commit()

	def find(self, keydict=None):
		try:
			return self.fetch(keydict=keydict)
		except NoResultFound, e:
			log.err("No results for %s.find(%s)", cn(self), keydict)

	def fetch(self, keydict=None):
		"""
		Keydict must be filter parameters that return exactly one record.
		"""
		session = SessionMixin.get_instance()
		if not keydict:
			keydict = self.key()
		return session.query(self.__class__).filter(**keydict).one()
		
	def exists(self):
		return self.fetch() != None 


class NodeSet(object):
	zope.interface.implements(taxus_out.INodeSet)
	def __init__(self, iterable):
		self.nodes = iterable

class ResultSet(NodeSet):
	#zope.interface.implements(taxus_out.INodeSet)
	def __init__(self, query, iterable):
		super(ResultSet, self).__init__(iterable)
		self.query = query



class Node(SqlBase, SessionMixin):
	"""
	Provide lookup on numeric ID, name (non-unique) and standard dates.
	"""

	zope.interface.implements(taxus_out.INode) # meaning I'face Node, not INode

	__tablename__ = 'nodes'
	id = Column(Integer, primary_key=True)

	ntype = Column('ntype', String(50))
	__mapper_args__ = {'polymorphic_on': ntype}
	
	name = Column(String(255), nullable=True)
	
	#space_id = Column(Integer, ForeignKey('nodes.id'))
	#space = relationship('Node', backref='children', remote_side='Node.id')
	
	date_added = Column(DateTime, index=True, nullable=False)
	deleted = Column(Boolean, index=True, default=False)
	date_deleted = Column(DateTime)


class ID(SqlBase, SessionMixin):

	"""
	A global identifier.
	"""

	zope.interface.implements(taxus_out.IID)

	__tablename__ = 'ids'
	id = Column(Integer, primary_key=True)

	date_added = Column(DateTime, index=True, nullable=False)
	deleted = Column(Boolean, index=True, default=False)
	date_deleted = Column(DateTime)


class Name(SqlBase, SessionMixin):

	"""
	A global identifier name.
	"""

	zope.interface.implements(taxus_out.IID)

	__tablename__ = 'ids_name'
	id = Column(Integer, primary_key=True)

	date_added = Column(DateTime, index=True, nullable=False)
	deleted = Column(Boolean, index=True, default=False)
	date_deleted = Column(DateTime)

	name = Column(String(255), index=True, unique=True)

	def __str__(self):
		return "<%s %r>" % (lib.cn(self), self.name)

	def __repr__(self):
		return "<Name %r>" % self.name

# mapping table for Host [1-1] Locator
#locator_host = Table('locator_host', SqlBase.metadata,
#	Column('locator_ida', ForeignKey('ids_lctr.id')),
#	Column('host_idb', ForeignKey('hosts.id'))
#)
# mapping table for ChecksumDigest [1-*] Locator
locators_checksum = Table('locators_checksum', SqlBase.metadata,
	Column('locators_ida', Integer, ForeignKey('ids_lctr.id')),
	Column('chk_idb', Integer, ForeignKey('ids_chk.id'))
)
# mapping table for Tag [*-*] Locator
locators_tags = Table('locators_tags', SqlBase.metadata,
	Column('locator_ida', Integer, ForeignKey('ids_lctr.id')),
	Column('tags_idb', Integer, ForeignKey('ids_tag.id'))
)

class Locator(SqlBase, SessionMixin):

	"""
	A global identifier for retrieval of remote content.
	
	Maybe based on DNS and route, script or filename for HTTP etc.
	For file based descriptors may be registered domain and filename, 
	but also IP and variants on netpath, even inode number lookups.

	sameAs
		Incorporates sameAs to indicate references which contain parametrization
		and are a variant or more specific form of another references,
		but essentially the same 'resource'. Note that references may point to other
		'things' than files or HTTP resources.

		A misleading example may be HTTP URLs which are path + query, even more a
		fragment. This can be misleading as URL routing is part of the web
		application framework and may serve other requirements than resource
		parametrization, and further parametrization may occur at other places
		(Headers, cookies, embedded, etc.). 
		
		The Locator sameAs allows comparison on references,
		comparison of the dereferenced objects belongs on other Taxus objects that
		refer to the Locator table.
	"""
	zope.interface.implements(taxus_out.IID)

	__tablename__ = 'ids_lctr'
	id = Column(Integer, primary_key=True)

	date_added = Column(DateTime, index=True, nullable=False)
	deleted = Column(Boolean, index=True, default=False)
	date_deleted = Column(DateTime)

	#ref = Column(String(255), index=True, unique=True)
	# XXX: varchar(255) would be much too small for many (web) URL locators 
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
		backref='location')
	tags = relationship('Tag', secondary=locators_tags,
		backref='locations')
	host_id = Column(Integer, ForeignKey('hosts.id'))
	host = relationship('Host', primaryjoin="Locator.host_id==Host.host_id",
		backref='locations')

	def __str__(self):
		return "<%s %r>" % (lib.cn(self), self.ref)


tag_namespace_table = Table('tag_namespace', SqlBase.metadata,
	Column('ids_tag_id', Integer, ForeignKey('ids_tags.id'), primary_key=True),
	Column('ns_id', Integer, ForeignKey('ns.id'), primary_key=True),
)
class Tag(Name):

	"""
	Tags primarily constitute a name unique within some namespace.
	They may be used as types or as instance identifiers.
	"""
	zope.interface.implements(taxus_out.IID)

	__tablename__ = 'ids_tag'
	id = Column(Integer, primary_key=True)

	name = Column(String(255), unique=True, nullable=True)
	#sid = Column(String(255), nullable=True)
	# XXX: perhaps add separate table for Tag.namespace attribute
	namespaces = relationship('Namespace', secondary=tag_namespace_table)
		backref='tags')


class Topic(Tag):
	"""
	A topic describes a subject; a theme, issue or matter, regarding something
	else. 
	XXX: It is the first of a level abstraction for other elementary types like
	inodes or document elements.
	For now, it is a succinct name on the Tag supertype, with an additional
	Text field for further specification.
	
	XXX: a basic type indicator to toggle between a thing or an idea.
	Names are given in singular form, a text field codes the plural for UI use.
	"""
	__tablename__ = 'ids_topic'
	explanation = Column(Text)
	thing = Column(Boolean)
	plural = Column(String)


class ChecksumDigest(SqlBase, SessionMixin):

	"""
	Superclass for fixed length content checksums
	and other lossy content digests.
	"""
	__tablename__ = 'ids_chk'

	id = Column(Integer, primary_key=True)

	date_added = Column(DateTime, index=True, nullable=False)
	deleted = Column(Boolean, index=True, default=False)
	date_deleted = Column(DateTime)

	digest_type = Column('digest_type', String(50))
	__mapper_args__ = {'polymorphic_on': digest_type}


class SHA1Digest(ChecksumDigest):
	"""
	A 160bit digest.
	"""
	__tablename__ = 'ids_chk_sha1'
	sha1_id = Column('id', Integer, ForeignKey('ids_chk.id'), primary_key=True)
	__mapper_args__ = {'polymorphic_identity': 'SHA1'}
	digest = Column(String(40), index=True, unique=True, nullable=False)


class MD5Digest(ChecksumDigest):
	"""
	A 128 bit digest.
	"""
	__tablename__ = 'ids_chk_md5'
	md5_id = Column('id', Integer, ForeignKey('ids_chk.id'), primary_key=True)
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


class Host(Node):
	"""
	"""
	__tablename__ = 'hosts'
	__mapper_args__ = {'polymorphic_identity': 'host'}

	host_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)
	hostname_id = Column(Integer, ForeignKey('ids_name.id'))
	hostname = relationship('Name', primaryjoin=hostname_id==Name.id)

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

def prompt_choice_with_input(promptstr, choices):
	assert isinstance(choices, list)
	i = 0
	for c in choices:
		i += 1
		promptstr += "\n%i. %s" % (i, c)
	x = raw_input(promptstr+'\n')
	if x.isdigit():
		return choices[int(x)-1]
	elif x:
		return x

def current_hostname(initialize=False, interactive=False):
	"""
	"""
	hostname = None

	hostname_file = os.path.expanduser('~/.cllct/host')
	if os.path.exists(hostname_file):
		hostname = open(hostname_file).read().strip()

	elif initialize:

		#assert not isinstance(hostname, (tuple, list)), hostname
		#print 'gethostbyaddr', hostname, '->', hostnames
		#fqdn = socket.getfqdn(), 

		hostname = socket.gethostname()
		hostnames = socket.gethostbyaddr(hostname)
		while True:
			if socket.getfqdn() != hostname:
				hostname = hostnames[0] +"."
			else:
				log.err("FQDN is same as hostname")
				# cannot figure out what host to use
				while interactive:
					hostname = prompt_choice_with_input("Which? ", hostnames[1])
					if hostname: break
				#if not interactive:
				#	raise ValueError("")
			if hostname:
				try:
					nameinfo((hostname, 80))
				except Exception, e:
					print 'Warning: Cannot resolve FQDN', e
				open(hostname_file, 'w+').write(hostname)
				print "Stored %s in %s" % (hostname, hostname_file)
				break
	return hostname

"""
::

       Node
        * id:Integer
        * ntype:String(50)
        * name:String(255)
        * dates
        A
        |
       INode
        * host:Host
        A
        |
     .--^--. -----. -------. ------. -----.
     |     |      |        |       |      |
    Dir   File   Device   Mount   FIFO   Socket

"""

inode_locator_table = Table('inode_locator', SqlBase.metadata,
	Column('inode_id', Integer, ForeignKey('inodes.id'), primary_key=True),
	Column('lctr_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True),
)

class INode(Node):

	"""
	Used for temporary things?
	Provide lookup on file-locator URI or file-inode URI.

	Abstraction of types of local filesystem resources, some of which are
	files. References to filelikes (file handlers or 'descriptor')  should be 
	abstracted another way, see Stream.

	It needs either a localname and volume (host+path) as reference,
	or use a set of bare references. 
	The latter is current.

	May be need volumes.. should need a way to lookup if a Locator is within
	some volume.
	It is convenient in early phase to use a bunch of references. But move to
	better structure later.
	
	TODO: implement __cmp__ for use with sameAs to query the host system
	TODO: should mirror host system attributes for dates, etc.
	"""

	__tablename__ = 'inodes'
	__mapper_args__ = {'polymorphic_identity': 'inode'}

	inode_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

	#inode_number = Column(Integer, unique=True)

	#filesystem_id = Column(Integer, ForeignKey('nodes.id'))

	#locator_id = Column(ForeignKey('ids_lctr.id'), index=True)
	#location = relationship(Locator, primaryjoin=locator_id == Locator.id)

	#local_path = Column(String(255), index=True, unique=True)

	#host_id = Column(Integer, ForeignKey('hosts.id'))
	#host = relationship(Host, primaryjoin=Host.host_id==host_id)

	locators = relationship('Locator', secondary=inode_locator_table)

	Dir = 'inode:dir'
	File = 'inode:file'
	Symlink = 'inode:symlink'
	Device = 'inode:device'
	Mount = 'inode:mount'
	FIFO = 'inode:fifo'
	Socket = 'inode:socket'

	@property
	def location(self):
		return "file:%s" % "/".join((self.host.netpath, self.local_path))

	def __unicode__(self):
		return u"<%s %s>" % (lib.cn(self), self.location)

	def __str__(self):
		return "<%s %s>" % (lib.cn(self), self.location)

	def __repr__(self):
		return "<%s %s>" % (lib.cn(self), self.location)



class Dir(INode):

	__tablename__ = 'dirs'
	__mapper_args__ = {'polymorphic_identity': INode.Dir}

	dir_id = Column('id', Integer, ForeignKey('inodes.id'), primary_key=True)

class File(INode):

	__tablename__ = 'files'
	__mapper_args__ = {'polymorphic_identity': INode.File}

	file_id = Column('id', Integer, ForeignKey('inodes.id'), primary_key=True)

class Symlink(INode):

	__tablename__ = 'symlinks'
	__mapper_args__ = {'polymorphic_identity': INode.Symlink}
	
	symlink_id = Column('id', Integer, ForeignKey('inodes.id'), primary_key=True)

class Device(INode):

	__tablename__ = 'devices'
	__mapper_args__ = {'polymorphic_identity': INode.Device}

	device_id = Column('id', Integer, ForeignKey('inodes.id'), primary_key=True)

class Mount(INode):

	__tablename__ = 'mounts'
	__mapper_args__ = {'polymorphic_identity': INode.Mount}

	mount_id = Column('id', Integer, ForeignKey('inodes.id'), primary_key=True)

class FIFO(INode):

	__tablename__ = 'fifos'
	__mapper_args__ = {'polymorphic_identity': INode.FIFO}

	fifo_id = Column('id', Integer, ForeignKey('inodes.id'), primary_key=True)

class Socket(INode):

	__tablename__ = 'sockets'
	__mapper_args__ = {'polymorphic_identity': INode.Socket}

	socket_id = Column('id', Integer, ForeignKey('inodes.id'), primary_key=True)


class CachedContent(INode):

	"""
	This is a pointer to a local path, that may or may not contain a cached
	resource. If (fully) retrieved, the entities body is located at local_path. 
	TODO: The entity headers can be reconstructed from DB and/or metafile or resource is filed as-is.
	Complete header information should be mantained when a CachedContent record is created. 
	"""

	__tablename__ = 'cnt'
	__mapper_args__ = {'polymorphic_identity': 'inode:cached-resource'}

	content_id = Column('id', Integer, ForeignKey('inodes.id'), primary_key=True)

	cid = Column(String(255), index=True, unique=True)
	size = Column(Integer, nullable=False)
	"The length of the raw data stream. "
	charset = Column(String(32))
	""
	partial = Column(Boolean)
	# RFC 2616 headers
	etag = Column(String(255))
	expires = Column(DateTime)
	encodings = Column(String(255))


doc_root_element_table = Table('doc_root_element', SqlBase.metadata,
	Column('inode_id', Integer, ForeignKey('inodes.id'), primary_key=True),
	Column('lctr_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True)
)

class Document(Node):
	"""
	After INode and Resource, the most abstract representation of a (file-based) 
	resource in taxus.
	A document comprises a set of elements in an unspecified further structure.

	Systems may allow muxing or demuxing a document from or resp. to its
	elements, Ie. the document object is interchangable by the set of its
	elements (although Node attributes may not be accounted for).

	sameAs
		Incorporates sameAs from N3 to indicate references that may have
		different access protocols but result in the same object
		(properties/actions)?
	"""
	elements = relationship('Element', secondary=doc_root_element_table)


class ReCoDoc(Document):
	"""
	ree-CO-doc, Recursive Container document describes the way hierarchical
	container based formats provide a serial view of systems and domain objects.

	Some may be canonical, or ambigious, generic or very specific, etc.
	It forces serialization and a way to look at the resource as a single
	stream with discrete, nested elements (iow. XML with either some DOMesque
	interface or serial access interface). 

	TODO: It implements sameAs to indicate ...
	"""
	__tablename__ = 'recodocs'
	__mapper_args__ = {'polymorphic_identity': 'recodoc'}
	host_id = Column(Integer, ForeignKey('hosts.id'))
	host = relationship('Host', primaryjoin="Locator.host_id==Host.host_id",
		backref='locations')

class Element(Node):
	"""
	Part of a Document.

	XXX: I've allowed for re-use by placing a list of element instances on the
	Document, instead of coding each element with an origin.

	XXX: Subtypes may specificy how Node attributes map to the element objects
	and/or additional attributes to consitute an element. E.g. an XML Subtype
	specifies a list with textnodes and/or elements, besides a tag and attributes.
	XML only has one rootelement per document.
	"""
	pass # not much to say yet. there is a numeric ID, (possibly unique) name,
	# dates and (possible) subtype. Not much else to say.

class Status(Node):

	"""
	Made this a node so it can be annotated, and perhaps expanded in the future
	to map equivalent codes in different protocols.
	"""

	__tablename__ = "status"
	__mapper_args__ = {'polymorphic_identity': 'status'}

	status_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

	http_code = Column(Integer, unique=True)

	#ref = Column(Integer, ForeignKey('nodes.id'))
	#description = Column(Text, index=True)


class Resource(Node):

	"""
	A generic resource description. A (web) document.
	Normally a subclass should be used for instances, choose between Invariant 
	if the document ought not to change,
	or choose Variant to indicate a more dynamic resource.
	Invariant resources are generally non-negotiated, but sometimes 
	a specific representation may be retrieved through negotiation on 
	an associated Variant resource.
	"""

	__tablename__ = 'res'
	__mapper_args__ = {'polymorphic_identity': 'resource'}

	resource_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

	status_id = Column(ForeignKey('status.http_code'), index=True)
	status = relationship(Status, primaryjoin=status_id == Status.http_code)

	locator_id = Column(ForeignKey('ids_lctr.id'), index=True)
	location = relationship(Locator, primaryjoin=locator_id == Locator.id)
	"Content-Location. , size=0"

	last_access = Column(DateTime)
	last_modified = Column(DateTime)
	last_update = Column(DateTime)

	# RFC 2616 headers
	allow = Column(String(255))

	# extension_headers  = Column(String())


resource_variant_table = Table('resource_variant', SqlBase.metadata,
	Column('res_ida', Integer, ForeignKey('res.id'), primary_key=True),
	Column('vres_idb', Integer, ForeignKey('vres.id'), primary_key=True),
#	mysql_engine='InnoDB', 
#	mysql_charset='utf8'
)

class Description(Node):

	"""
    A scheme+localname.
	"""

	__tablename__ = 'frags'
	__mapper_args__ = {'polymorphic_identity': 'fragment'}

	fragment_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

#	namespace_id = Column(Integer, ForeignKey('ns.id'))
#	namespace = relationship('Namespace', 
#			primaryjoin='namespace_id==Namespace.namespace_id')

	variants = relationship('Variant', backref='descriptions',
			secondary=fragment_variant_table)


class Comment(Description):

	__tablename__ = 'comments'
	__mapper_args__ = {'polymorphic_identity': 'fragment:comment'}

	comment_id = Column('id', Integer, ForeignKey('frags.id'), primary_key=True)

	annotated_node = Column(Integer, ForeignKey('nodes.id'))
	node = relationship(Node, 
			primaryjoin=annotated_node==Node.id)
	comment = Column(Text)


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


class Invariant(Resource):

	"""
	A resource consisting of a single datastream. 
	As a general rule, Invariants should not change their semantic content,
	but may allow differation in the codec stack used.

	Ideally, a Variant can capture all parameters of an Resource
	and with that manage all possible Invariants.
	"""

	__tablename__ = 'ivres'
	__mapper_args__ = {'polymorphic_identity': 'resource:invariant'}

	invariant_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

	content_id = Column(Integer, ForeignKey('cnt.cid'), index=True)
	content = relationship(CachedContent,
			primaryjoin=content_id==CachedContent.cid)
	"A specification of the contents. "

	# RFC 2616 headers
	language = Column(String(255))
	mediatype = Column(String(255))


class Variant(Resource):

	"""
	A resource the content of which comes with several variations, such as
	output format, natural language, quality indicators, and/or other features.

	Mechanisms for variation include client-negotiated capabilities such as 
	peripheral abilities to render or interact with specific media/services.
	"""

	__tablename__ = 'vres'
	__mapper_args__ = {'polymorphic_identity': 'resource:variant'}

	variant_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

	# FIXME: vary information not stored
	# Structure for vary is given in RFC draft on HTTP TCN and RVSA. 

	# descriptions - many-to-may to Description.variants


class QName():
	pass#ns = ...



class Namespace(Variant):
	"""
	A set of unique names. 

	The namespace at a minimum has an system identifier,
	which may refer to one or more global identifiers.

	XXX: A collection of anything? What.
	See Tag, a namespace constituting distinct tag types. 
	But also code, objects.
	XXX: there is no mux/demux (yet) so subclassing variant does not mean much, but anyway.
	XXX: Being a variant, the canonical URL, may be used as identifier, may be
	stored at related Invariant record. some consideration needs to go there
	"""
	__tablename__ = 'ns'
	__mapper_args__ = {'polymorphic_identity': 'resource:variant:namespace'}

	namespace_id = Column('id', Integer, ForeignKey('vres.id'), primary_key=True)

	# tags = *Tag; see relationship in tag_namespace_table

	# FIXME: where does the prefix go

#class BoundNamespace(ID):
#	__tablename__ = 'ns_bid'
#	__mapper_args__ = {'polymorphic_identity': 'id:namespace'}
#
#	prefix = Column(String(255), unique=True)

class Schema(Variant):
	"""
	TODO This would define schema information for or one more namespaces.
	"""
	__tablename__ = 'schema'
	__mapper_args__ = {'polymorphic_identity': 'resource:variant:schema'}

	namespaces = []




class Relocated(Resource):

	__tablename__ = 'relocated'
	__mapper_args__ = {'polymorphic_identity': 'resource:relocated'}

	relocated_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

	refnew_id = Column(ForeignKey('ids_lctr.id'), index=True)
	redirect = relationship(Locator, primaryjoin=refnew_id == Locator.id)

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
			primaryjoin=node_id == Node.id)


class Bookmark(Resource):

	"""
	A textual annotation with a short and long descriptive label,
	a sequence of tags, the regular set of dates, 
	and is itself a resource.
	"""

	__tablename__ = 'bm'
#	__table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
	__mapper_args__ = {'polymorphic_identity': 'resource:bookmark'}

	bookmark_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

	ref_id = Column(Integer, ForeignKey('ids_lctr.id'))
	ref = relationship(Locator, primaryjoin=Locator.id==ref_id)

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

	id = Column(Integer, ForeignKey('res.id'), primary_key=True)

	refs = relationship(Locator, secondary=workset_locator_table)


token_locator_table = Table('token_locator', SqlBase.metadata,
	Column('left_id', Integer, ForeignKey('stk.id'), primary_key=True),
	Column('right_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True),
)


class Token(Node):

	"""
	A large-value variant on Tag, perhaps should make this a typetree.
	"""

	__tablename__ = 'stk'
#	__table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
	__mapper_args__ = {'polymorphic_identity': 'meta:security-token'}

	id = Column(Integer, ForeignKey('nodes.id'), primary_key=True)

	value = Column(Text(65535))#, index=True, nullable=True)
	refs = relationship(Locator, secondary=token_locator_table)


def get_session(dbref, initialize=False):
	engine = create_engine(dbref)#, encoding='utf8')
	#engine.raw_connection().connection.text_factory = unicode
	if initialize:
		log.info("Applying SQL DDL to DB %s ", dbref)
		SqlBase.metadata.create_all(engine)  # issue DDL create 
		print 'Updated schema'
	session = sessionmaker(bind=engine)()
	return session
#   dbref='mysql://scrow-user:p98wa7txp9zx@sam/scrow'
#   engine = create_engine(dbref, encoding='utf8', convert_unicode=False)
#	engine = create_engine('sqlite:///test.sqlite')#, echo=True)

	#dbref = 'mysql://robin/taxus'
	#dbref = 'mysql://robin/taxus_o'


class Taxus(object):

	# Extra commands
	def init_host(self, options=None):
		"""
		Tie Host to current system. Initialize Host if needed. 
		"""
#		assert self.volumedb, "Must have DB first "
		hostnamestr = current_hostname(True, options.interactive)
		assert hostnamestr
		hostname = self.hostname_find([hostnamestr], options)
		if not hostname:
			hostname = Name(name=hostnamestr,
					date_added=datetime.now())
			hostname.commit()
		assert hostname
		host = self.host_find([hostname], options)
		if not host:
			host = Host(hostname=hostname,
					date_added=datetime.now())
			host.commit()
		assert host
		print "Initialized host:"
		print taxus_out.IFormatted(host).__str__()
		return host

	def init_database(self, options=None):
		dbref = options.dbref
		print "Applying SQL DDL to DB %s " % dbref
		self.session = get_session(dbref, initialize=True)
		return self.session

	def find_inode(self, path):
		# FIXME: rwrite to locator?
		inode = INode(local_path=path)
		inode.host = self.find_host()
		return inode

	def query(self, *args, **opts):
		print 'TODO: query:',args
		q = self.session.query(Node)
		return ResultSet(q, q.all())

	subcmd_aliases = {
			'rm': 'remove',
			'upd': 'update',
		}

	def node(self, *args, **opts):
		subcmd = args[0]
		while subcmd in subcmd_aliases:
			subcmd = subcmd_aliases[subcmd]
		assert subcmd in ('add', 'update', 'remove'), subcmd
		getattr(self, subcmd)(args[1:], **opts)
	   
	def node_add(self, name, **opts):
		"Don't call this directly from CL. "
		s = get_session(opts.get('dbref'))
		node = Node(name=name, 
				date_added=datetime.now())
		s.add(node)
		return node

	def node_remove(self, *args, **opts):
		s = get_session(opts.get('dbref'))
		pass # TODO: node rm
		return
		node = None#s.query(Node).
		node.deleted = True
		node.date_deleted = datetime.now()
		s.add(node)
		s.commit()
		return node

	def node_update(self, *args, **opts):
		pass # TODO: node update

#	def namespace_add(self, name, prefix, uri, **opts):
#		uriref = Locator(ref=uri)
#		node = Namespace(name=name, prefix=prefix, locator=uriref,
#				date_added=datetime.now())
#		s.add(node)
#		s.commit()
#		return node

#	def description_new(self, name, ns_uri):
#		Description(name=name, 
#				date_added=datetime.now())

	def comment_new(self, name, comment, ns, node):
		#NS = self.
		node = Comment( name=name,
				#namespace=NS,
				annotated_node=node,
				comment=comment,
				date_added=datetime.now())
		return node

