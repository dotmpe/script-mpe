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

TODO: add files to global index manually.
TODO: map manualy added paths elements to GroupNode, relative paths? entered paths are
  important, watch out for bash globbing.
TODO: some checksums for my precious media. Could use sums somehow to tie..
TODO: tagging? or not. 
"""
import os
from datetime import datetime

from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index, DateTime, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref

import lib
import log
import libcmd
import res.fs
import taxus.core
import taxus.media
import taxus.model
import taxus.web
import taxus.semweb
import taxus.net
import taxus.generic
import taxus.checksum
import taxus.fs
from taxus.core import Node, Name
from taxus.media import Mediatype, Mediaformat, Genre, Mediameta
from txs import TaxusFe


"""
class FileDescription(Node):
    __tablename__ = 'filedescription'
    __mapper_args__ = {'polymorphic_identity': 'filedescription'}

    filedescription_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)
    description = Column(String(255), unique=True)

ass FileInfo(Node):
    __tablename__ = 'fileinfo'
    __mapper_args__ = {'polymorphic_identity': 'filedescription'}
    fileinfo_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    inode_id = Column('inode_id', ForeignKey('inodes.id'))
    inode = relationship(INode, primaryjoin= inode_id == INode.inode_id )

    description_id = Column(ForeignKey('filedescription.id'), index=True)
    description = relationship(FileDescription, 
            primaryjoin=description_id == FileDescription.filedescription_id)
"""

class FileInfoApp(TaxusFe):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

#    DB_PATH = os.path.expanduser('~/.fileinfo.db')
#    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

#    TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['file_info']
    #NONTRANSIENT_OPTS = Cmd.NONTRANSIENT_OPTS 
    DEFAULT_ACTION = 'file_info'

    DEPENDS = {
            'file_info': ['txs_session'],
            'name_and_categorize': ['txs_session'],
            'mm_stats': ['txs_session'],
            'list_mtype': ['txs_session'],
            'list_mformat': ['txs_session'],
            'add_mtype': ['txs_session'],
            'add_mformat': ['txs_session']
        }

    @classmethod
    def get_optspec(Klass, inherit):
        return (
                (('--file-info',), libcmd.cmddict(help="Default command. ")),
                (('--name-and-categorize',), libcmd.cmddict(
                    help="Need either --interactive, or --name, --mediatype and "
                        " --mediaformat. Optionally provide one or more --genre's. "
                )),
                (('--mm-stats',), libcmd.cmddict(help="Print media stats. ")),
                (('--list-mtype',), libcmd.cmddict(help="List all mediatypes. ")),
                (('--list-mformat',), libcmd.cmddict(help="List all media formats. ")),
                (('--add-mtype',), libcmd.cmddict(help="Add a new mediatype. ")),
                (('--add-mformat',), libcmd.cmddict(help="Add a new media format. ")),
                (('--add-genre',), libcmd.cmddict(help="Add a new media genre. ")),

                (('--name',), dict(
                    type='str'
                )),
                (('--mtype',), dict(
                    type='str'
                )),
                (('--mformat',), dict(
                    type='str'
                )),
                (('--genres',), dict(
                    action='append',
                    default=[],
                    type='str'
                ))
               # (('-d', '--dbref'), {'default':self.DEFAULT_DB, 'metavar':'DB'}),
            )

    def list_mformat(self, sa=None):
        mfs = sa.query(Mediaformat).all()
        for mf in mfs:
            print mf

    def list_mtype(self, sa=None):
        mms = sa.query(Mediatype).all()
        for mm in mms:
            print mm

    def mm_stats(self, sa=None):
        mfs = sa.query(Mediaformat).count()
        log.note("Number of mediaformat's: %s", mfs)
        mts = sa.query(Mediatype).count()
        log.note("Number of mediatype's: %s", mts)
        mms = sa.query(Mediameta).count()
        log.note("Number of mediameta's: %s", mms)

    def add_mtype(self, mtype, label, opts=None, sa=None):
        """
        Add one or more new mediatypes.
        """
        assert mtype, "First argument 'mtype' required. "
        mt = sa.query( Mediatype, Name )\
                .filter( Name.name == mtype )\
                .all()
        if mt:
            mt = mt[0]
        if mt:
            log.warn('Existing mtype %s', mt)
            yield 1
        if not label:
            label = mtype
        mtn = Name( name=mtype, date_added=datetime.now() )
        mt = Mediatype( name=label, mime=mtn, date_added=datetime.now() )
        log.info('New type %s', mt)
        sa.add(mt)
        sa.commit()

    def add_mformat(self, opts=None, sa=None, *formats):
        """
        Add one or more new mediaformats.
        """
        for fmt in formats:
            mf = Mediaformat.find((
                    Mediaformat.name == fmt,
                ), sa=sa)
            if mf:
                log.warn('Existing mformat %s', mf)
                continue
            if opts.interactive: # XXX: add_mformat interactive
                mfs = Mediaformat.search(name=fmt)
                print 'TODO', mfs
            mf = Mediaformat( name=fmt, date_added=datetime.now() )
            log.info('New format %s', mf)
            sa.add(mf)
        sa.commit()

# TODO: adding Mediameta for files
    def name_and_categorize(self, args=None, opts=None, sa=None, 
            name=None, mtype=None, mformat=None, genres=None):
        assert args, args
        path = args[0]
        assert os.path.exists(path), path
        assert sa, sa
        assert name, name
        mm = Mediameta(name=name)
#        if mtype:
#            mt = sa.query(Mediatype)\
#                    .filter(Mediatype.name == mediatype)\
#                    .all()
#            print 'mediatype', mt

    def file_info(self, args=None, sa=None):
        for p in args:
            for p in res.fs.Dir.walk(p):
                format_description = lib.cmd('file -bs "%s"', p).strip()
                mediatype = lib.cmd('file -bi "%s"', p).strip()
                print ':path:', p, format_description
                print ':mt:', mediatype
                print


if __name__ == '__main__':
    FileInfoApp.main()

