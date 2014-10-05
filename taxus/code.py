"""
Version Control
"""
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, Enum
from sqlalchemy.orm import relationship, backref

import core
import net
from init import SqlBase
from util import ORMMixin



projects_hosts_table = Table('projects_hosts', SqlBase.metadata,
    Column('proj_id', Integer, ForeignKey('projects.id'), primary_key=True),
    Column('host_id', Integer, ForeignKey('hosts.id'), primary_key=True)
)

projects_vcs_table = Table('projects_vcs', SqlBase.metadata,
    Column('proj_id', Integer, ForeignKey('projects.id'), primary_key=True),
    Column('vc_id', Integer, ForeignKey('vcs.id'), primary_key=True)
)


class VersionControl(SqlBase, ORMMixin):#core.Node):

    __tablename__ = 'vcs'
    #__mapper_args__ = {'polymorphic_identity': 'vc'}

    vc_id = Column('id', Integer, primary_key=True)

    #vc_type_id = Column(Integer, ForeignKey('nodes.id'), nullable=False)
    #vc_type = relationship( core.Node, primaryjoin= vc_type_id==core.Node.node_id )

    vc_type = Column(Enum('GIT', 'BazaarNG', 'Mercurial', 'Subversion', 'CVS'),
            nullable=False)

    host_id = Column(Integer, ForeignKey('hosts.id'), nullable=False)
    host = relationship( net.Host, 
            primaryjoin= host_id == net.Host.host_id,
            backref="repositories")

    path = Column(String(255), nullable=False)


class Project(SqlBase, ORMMixin):

    __tablename__ = 'projects'

    project_id = Column('id', Integer, primary_key=True)

    name = Column(String(255), nullable=False, index=True, unique=True)

    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)

    hosts = relationship( net.Host, 
            secondary=projects_hosts_table,
            backref="projects")

    repositories = relationship( VersionControl, 
            secondary=projects_vcs_table,
            backref="projects")

    #project_type = Column('type', String(50), nullable=False)
    #__mapper_args__ = {
    #        'polymorphic_on': project_type, 'polymorphic_identity': 'project'}

    def __repr__(self):
        return "<%s at %s for %r>" % (lib.cn(self), hex(id(self)), self.name)

    def __str__(self):
        return "%s for %r" % (lib.cn(self), self.name)


models = [
        VersionControl, Project
    ]


