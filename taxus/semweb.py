

class Description(Node):

	"""
	A.k.a. fragment or hash-URI.

	Denotes the ID of the entity represented by a resources. Not all
	implementations may provide such but nevertheless, the specific state is
	there and may be described. Current practice suggest each state is bound
	to a specific DOM node of the current representation. 

	XXX: Note that the actual string representation is intentionally not persisted.
		Still do this in Fragment subclass?

	Discussion
	-----------
	Ex: ../index.html is the ID and locator to a HTML document representing a
	directory, which itself might be identified by .../index.html# or even
	.../#fs:inode:123 if you want to stretch this example.
   
	Don't forget the fragment is handled entirely client-side, and in general 
	interpreted by graphical clients to correspond to an `id` attribute in an 
	XML'esque document, as per W3C standard. 
	These clients will never include that part in its request line.

	Using the fragment part, interactive clients may create unqiue URL's for 
	its various dynamic document states. Meaning each of these states is 
	treated as variant representations of an original server-rendered resource.
	Also, the URIs allow the client to record and navigate history and "bookmark
	pages", ie. annotate resources with card metadata.

	Further implementation
	-------------------------
	Fragment parts used like this usually hold one or more parameter to define 
	the current dynamic representation. This somewhat hurts the good practice of
	using proper named ID's as XML Schema and RDF N3 encourage. It also
	duplicates syntax from the query and path parameter parts, which are 
	readily supported by legions of IETF compliant libraries. 
	
	Consolidation 
	would require transparency of the client-side state on the server-side. 
	Ie., the server would have been able to render each and every fragment
	representation that the client can build up asychronously.
	"""

	__tablename__ = 'frags'
	__mapper_args__ = {'polymorphic_identity': 'fragment'}

	fragment_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

#	namespace_id = Column(Integer, ForeignKey('ns.id'))
#	namespace = relationship('Namespace', 
#			primaryjoin='namespace_id==Namespace.namespace_id')

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


