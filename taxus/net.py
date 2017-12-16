from datetime import datetime

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship, backref

from script_mpe import lib
from .init import SqlBase
from .util import ORMMixin, current_hostname
from .mixin import CardMixin
from . import core
from . import util
from . import iface
from . import checksum


class Domain(core.Name):

    """
    """

    __tablename__ = 'domains'
    __mapper_args__ = {'polymorphic_identity': 'domain'}

    domain_id = Column('id', Integer, ForeignKey('names.id'), primary_key=True)


class Host(Domain):

    """
    """

    __tablename__ = 'hosts'
    __mapper_args__ = {'polymorphic_identity': 'host'}

    host_id = Column('id', Integer, ForeignKey('domains.id'), primary_key=True)

    @classmethod
    def current(Klass, sa=None, session='default'):
        hostname_ = current_hostname()
        return Klass.fetch(filters=(Klass.name == hostname_,), sa=sa, session=session)

    @classmethod
    def init(Klass, sa=None, session='default'):
        host = Klass.current(sa=sa, session=session)
        if host:
            return host
        if not sa:
            sa = Klass.get_session(session=session)
        hostname = current_hostname(initialize=True)
        host = Klass(name = hostname, date_added=datetime.now())
        sa.add(host)
        sa.commit()
        return host

    @property
    def netpath(self):
        return "//%s" % self.name

    def __str__(self):
        return "Host %s" % ( self.name )

    def __repr__(self):
        return "<Host at % with %r>" % ( hex(id(self)), self.hostname )


# mapping table for Host [1-1] Locator
#locator_host = Table('locator_host', SqlBase.metadata,
#    Column('locator_ida', ForeignKey('ids_lctr.id')),
#    Column('host_idb', ForeignKey('hosts.id'))
#)
# mapping table for ChecksumDigest Locator
locators_checksums = Table('locators_checksums', SqlBase.metadata,
    Column('locators_ida', ForeignKey('ids_lctr.id')),
    Column('chk_idb', ForeignKey('chks.id'))
)
# mapping table for Tag [*-*] Locator
locators_tags = Table('locators_tags', SqlBase.metadata,
    Column('locator_ida', ForeignKey('ids_lctr.id')),
    Column('tags_idb', ForeignKey('names_tag.id'))
)

#class Locator(core.ID):
class Locator(SqlBase, CardMixin, ORMMixin):

    """
    A global identifier for retrieval of local or remote content.

    Regular known schema are tied to protocols, ie. http, ftp, .. gopher.
    Some more specific to applications, ie. wrt. mediafiles or distributed, P2P
    content.

    Use htdocs: scheme to standardize adressing of Taxus et al.
    core.Scheme and subtypes are used to manage instances of protocols,
    and other htdocs sub-schemes.
    """
    zope.interface.implements(iface.IID)

    __tablename__ = 'ids_lctr'
    lctr_id = Column('id', Integer, primary_key=True)

    idtype = Column(String(50), nullable=False)
    __mapper_args__ = {'polymorphic_on': idtype, 'polymorphic_identity': 'id:locator'}

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
        # FIXME: return bare path of Locator?
        if self.host:
            if ref.startswith("//"): # remove netpath
                assert ref.startswith('//'+self.host.name)
                ref = ref[2+len(self.host.name):]
            return ref
        else:
            assert ref.startswith('//'), ref
            ref = ref[2:]
            p = ref.find('/')
            if p != -1: # split of host
                return ref[p:]
            else:
                assert not "No path", ref

    checksums = relationship('ChecksumDigest', secondary=locators_checksums,
        backref='locations')

    domain_id = Column(Integer, ForeignKey('domains.id'))
    domain = relationship('Host', primaryjoin="Locator.domain_id==Host.domain_id",
        backref='locations')

    ref_md5_id = Column(Integer, ForeignKey('chks_md5.id'))
    ref_md5 = relationship(checksum.MD5Digest, primaryjoin=ref_md5_id==checksum.MD5Digest.md5_id)
    "A checksum for the complete reference, XXX to use while shortref missing? "

    ref_sha1_id = Column(Integer, ForeignKey('chks_sha1.id'))
    ref_sha1 = relationship(checksum.SHA1Digest, primaryjoin=ref_sha1_id==checksum.SHA1Digest.sha1_id)
    "A checksum for the complete reference, XXX to use while shortref missing? "

    def __str__(self):
        return "%s %r" % (lib.cn(self), self.ref or self.href())

    @property
    def href(self):
        return self.ref

    @classmethod
    def keys(klass):
        "Return SQL columns"
        return CardMixin.keys + 'domain ref_md5 ref_sha1'.split(' ')

    def to_dict(self, d={}):
        d.update(dict(href=self.ref))
        return ORMMixin.to_dict(self, d=d)


class URL(Locator):

    __tablename__ = 'ids_lctr_url'
    __mapper_args__ = {'polymorphic_identity': 'id:locator:url'}

    url_id = Column('id', Integer, ForeignKey('ids_lctr.id'), primary_key=True)
    ref = Column(Text)

    def href(self):
        return self.ref


token_locator_table = Table('token_locator', SqlBase.metadata,
    Column('left_id', Integer, ForeignKey('stk.id'), primary_key=True),
    Column('right_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True),
)


class Token(util.SqlBase, util.ORMMixin):

    """
    A large-value variant on Tag, perhaps should make this a typetree.
    """

    __tablename__ = 'stk'
    __mapper_args__ = {'polymorphic_identity': 'meta:security-token'}

    token_id = Column('id', Integer, primary_key=True)

    value = Column(Text(65535), nullable=True)
    refs = relationship(Locator, secondary=token_locator_table)


models = [
        Domain, Host, Locator, Token
    ]
