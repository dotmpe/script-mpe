#!/usr/bin/env python
"""
TODO: Keep catalog of file format descriptions for local paths
XXX: Verify valid extensions for format. 
XXX: Keep complete resource description

Schema
------
::

   FileInfo
    * inode:INode
    * description:FileDescription

   FileDescription
    * description:String(255)

"""
import optparse
import os
import subprocess
import sys

from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index, DateTime, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

from libcmd import Cmd, err
import confparse
from taxus import Node, INode, initialize


class FileDescription(Node):
    __tablename__ = 'filedescription'
    __mapper_args__ = {'polymorphic_identity': 'filedescription'}
    filedescription_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)
    description = Column(String(255), unique=True)

class FileInfo(Node):
    __tablename__ = 'fileinfo'
    __mapper_args__ = {'polymorphic_identity': 'filedescription'}
    fileinfo_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)
    inode_id = Column('inode_id', ForeignKey('inodes.id'))
    inode = relationship(INode, primaryjoin= inode_id == INode.inode_id )
    description_id = Column(ForeignKey('filedescription.id'), index=True)
    description = relationship(FileDescription, 
            primaryjoin=description_id == FileDescription.filedescription_id)

class FileInfoApp(Cmd):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DB_PATH = os.path.expanduser('~/.fileinfo.db')
    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

    TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['file_info']
    NONTRANSIENT_OPTS = Cmd.NONTRANSIENT_OPTS 
    DEFAULT_ACTION = 'file_info'

    def get_opts(self):
        return Cmd.get_opts(self) + (
                (('-d', '--dbref'), {'default':self.DEFAULT_DB, 'metavar':'DB'}),
            )

    def init_config_defaults(self):
        pass

    def file_info(self, *paths, **kwds):
        for p in paths:
            if not os.path.isfile(p):
                err("Ignored non-file %s", p)
                continue
            stdin,stdout,stderr = os.popen3('file -bs %s' % p)
            #TODO:stdin,stdout,stderr = subprocess.popen3('file -s %s' % p)
            stdin.close()
            errors = stderr.read()
            if errors:
                err(errors)
            format_description = stdout.read().strip()
            print p, format_description

if __name__ == '__main__':
    FileInfoApp().main()

# vim:et:
