import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship, backref

from .init import SqlBase
from .util import ORMMixin
from .mixin import CardMixin, ResourceMixin
from . import core
from . import net
from . import fs


class CachedContent(fs.INode):

    """
    This is a pointer to a local path, that may or may not contain a cached
    resource. If (fully) retrieved, the entities body is located at local_path.
    TODO: The entity headers can be reconstructed from DB and/or metafile or resource is filed as-is.
    Complete header information should be mantained when a CachedContent record is created.
    """

    __tablename__ = 'ccnt'
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


class Status(SqlBase, CardMixin, ORMMixin):

    """
    Made this a node so it can be annotated, and perhaps expanded in the future
    to map equivalent codes in different protocols.
    """

    __tablename__ = "status"
    status_id = Column('id', Integer, primary_key=True)

    code = Column(Integer, unique=True)
    phrase = Column(String(255), index=True)
    description = Column(Text(65535))

    # Relation to definition (protocol-spec/section)
    ref_id = Column(Integer, ForeignKey('ids_lctr_localname.id'))
    ref = relationship('Localname', primaryjoin='Localname.localname_id==Status.ref_id')


class Resource(SqlBase, CardMixin, ResourceMixin, ORMMixin):

    """
    A generic resource description. A (web) document, work, or some other
    abstraction of value.
    Normally a specific subclass should be used for instances.

    Choose subclass Invariant if the resource at the URL is static
    (ie. of a fixed MIME type, including any parameters),
    and Variant to indicate a dynamic resource.
    Invariant resources are non-negotiated.
    A specific representation may be retrieved through negotiation on
    an associated Variant resource.

    The RESTful way is Invariant content resources having URLs,
    however far more client friendly (or specific) URLs can transparently
    negotiate different representations of the content and/or may represent more abstract concepts.
    In the simplest case, a resource is a file  ie. a static resource.
    And depending on the web server handler this file may be parsed and
    processed and can consequently vary.

    Generally new types of resources will subtype Variant while they are
    under the user or programs control. In which case generating
    associated Invariant URLs is dynamic and elsewhere as well.
    """

    __tablename__ = 'res'
    __mapper_args__ = {'polymorphic_identity': 'resource'}

    resource_id = Column('id', Integer, primary_key=True)

    locator_id = Column(ForeignKey('ids_lctr.id'), index=True)
    location = relationship(net.Locator, primaryjoin=locator_id == net.Locator.lctr_id)
    "Content-Location. , size=0"

    # RFC 2616 headers
    allow = Column(String(255))
    http_status = Column(Integer) # TODO: HEAD? GET?
    # extension_headers  = Column(String())

    @classmethod
    def keys(klass):
        return CardMixin.keys + ResourceMixin.keys + \
            'resource_id location http_status'.split(' ')

    @property
    def href(self):
        return self.location.href()


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

    content_id = Column(Integer, ForeignKey('ccnt.id'), index=True)
    content = relationship(CachedContent,
            primaryjoin=content_id==CachedContent.content_id)
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


class RemoteCachedResource(Resource):

    __tablename__ = 'rcres'
    __mapper_args__ = {'polymorphic_identity': 'resource:cached'}

    remotecachedresource_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    # Relation to cache service
    rcres_type_id = Column(Integer, ForeignKey('ns.id'))
    rcres_type = relationship('Namespace', primaryjoin='Namespace.namespace_id==RemoteCachedResource.rcres_type_id')


models = [ CachedContent, Status, Resource, Variant, Invariant,
        RemoteCachedResource ]
