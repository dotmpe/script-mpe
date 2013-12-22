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



class Schema(Variant):
	"""
	TODO This would define schema information for or one more namespaces.
	"""
	__tablename__ = 'schema'
	__mapper_args__ = {'polymorphic_identity': 'resource:variant:schema'}

	namespaces = []








