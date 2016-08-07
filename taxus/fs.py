import os
import stat
from datetime import datetime

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref

# script Namespace
from script_mpe import log
# script.res Namespace
import core
import out
from init import SqlBase


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

class INode(core.Node):

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
        "Construct global, host-based file-locator"
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



models = [ INode, Dir, File, Symlink, Device, Mount, FIFO, Socket ]
