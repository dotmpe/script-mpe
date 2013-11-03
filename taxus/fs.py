import os
import stat
from datetime import datetime

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
	ForeignKey, Table, Index, DateTime
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref

# script Namespace
import log
# script.res Namespace
import core
import out
from util import SessionMixin
from init import SqlBase


class INode(core.Node):

	__tablename__ = 'inodes'
	__mapper_args__ = {'polymorphic_identity': 'inode'}

	inode_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

	#filesystem_id = Column(Integer, ForeignKey('nodes.id'))
	#filesystem = relationship(Node, primaryjoin=Node.node_id == filesystem_id)

	local_path = Column(String(255), index=True, unique=True)

	Dir = 'inode:dir'
	File = 'inode:file'
	Symlink = 'inode:symlink'
	Device = 'inode:device'
	Mount = 'inode:mount'
	FIFO = 'inode:fifo'
	Socket = 'inode:socket'

	@property
	def location(self):
		lp = self.local_path
		if lp[0] == '/':
			return "file:///%s" % (lp)
		else:
			return "file:%s" % (lp)

	def __str__(self):
		return "<%s %s>" % (out.cn(self), self.location)

	def __repr__(self):
		return "<%s %s>" % (out.cn(self), self.location)


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


class LocalPathResolver(object):

	def __init__(self, host, sasession):
		self.host = host
		self.sa = sasession

	def getDir(self, path, opts, exists=True):
		"""
		Return INode object for directory.
		"""
		if exists:
			assert os.path.isdir(path), "Missing %s"%path
		node = self.get(path, opts)
		assert node, "Missing path <%s>"%path
		return node

	def get(self, path, opts):
		ref = "file:%s%s" % (self.host.netpath, path)
		try:
			return self.sa.query(INode)\
					.filter(core.Node.ntype == INode.Dir)\
					.filter(INode.local_path == path)\
					.one()
		except NoResultFound, e:
			pass
		if not opts.init:
			log.warn("Not a known path %s", path)
			return
		log.debug("Initializing node for path %s", path)
		#locator = Locator(
		#		ref=ref,
		#		date_added=datetime.now())
		#locator.commit()
		ntype = self.get_type(path)
		clss = self.get_class(ntype)
		#print locator
		inode = clss(
				ntype=ntype,
				local_path=path,
#				location=locator,
				date_added=datetime.now())
		inode.commit()
		log.note("New local path %s node for %s: %s", out.cn(inode), path, inode)
		return inode

	def get_type(self, path):
		mode = os.stat(path).st_mode
		if stat.S_ISLNK(mode):#os.path.islink(path)
			return INode.Symlink
		elif stat.S_ISFIFO(mode):
			return INode.FIFO
		elif stat.S_ISBLK(mode):
			return INode.Device
		elif stat.S_ISSOCK(mode):
			return INode.Socket
		elif os.path.ismount(path):
			return INode.Mount
		elif stat.S_ISDIR(mode):#os.path.isdir(path):
			return INode.Dir
		elif stat.S_ISREG(mode):#os.path.isfile(path):
			return INode.File

	def get_class(self, ntype):
		if ntype == INode.Symlink:
			return Symlink
		elif ntype == INode.FIFO:
			return FIFO
		elif ntype == INode.Device:
			return Device
		elif ntype == INode.Socket:
			return Socket
		elif ntype == INode.Mount:
			return Mount
		elif ntype == INode.Dir:
			return Dir
		elif ntype == INode.File:
			return File




