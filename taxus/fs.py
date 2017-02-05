import os
import stat
from datetime import datetime

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref

# script Namespace
from script_mpe import lib, log
# script.res Namespace
from . import core
from . import net
from . import out
from .init import SqlBase


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

class INode(core.Name):

    """
    Provide lookup on file-locator URI or file-inode URI.

    TODO: implement __cmp__ for use with sameAs to query the host system
    TODO: should mirror host system attributes for dates, etc.
    """

    __tablename__ = 'inodes'
    __mapper_args__ = {'polymorphic_identity': 'inode'}

    inode_id = Column('id', Integer, ForeignKey('names.id'), primary_key=True)

    #inode_number = Column(Integer, unique=True)

    #filesystem_id = Column(Integer, ForeignKey('nodes.id'))

    #locator_id = Column(ForeignKey('ids_lctr.id'), index=True)
    #location = relationship(Locator, primaryjoin=locator_id == Locator.id)

    #local_path = Column(String(255), index=True, unique=True)

    #host_id = Column(Integer, ForeignKey('hosts.id'))
    #host = relationship(net.Host, primaryjoin=net.Host.host_id==host_id)

    date_created = Column(DateTime, index=True, nullable=True)
    date_accessed = Column(DateTime, index=True, nullable=False)
    date_modified = Column(DateTime, index=True, nullable=False)

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
        return "file:%s" % "/".join((self.host.netpath, self.name))

    @property
    def record_name(self):
        return self.ntype +':'+ self.name

    def __unicode__(self):
        return "<%s %s>" % (lib.cn(self), self.record_name)

    def __str__(self):
        return "<%s %s>" % (lib.cn(self), self.record_name)

    def __repr__(self):
        return "<%s %s>" % (lib.cn(self), self.record_name)



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


class Disk(core.Name):

    """
    A block storage device with one or more volumes.
    """

    __tablename__ = 'disks'
    __mapper_args__ = {'polymorphic_identity': 'disk-name'}

    disk_id = Column('id', Integer, ForeignKey('names.id'), primary_key=True)

    # volumes = relationship('Volume',
    "Links to the partitions (root-volumes) of the disk. "


models = [ INode, Dir, File, Symlink, Device, Mount, FIFO, Socket ]
