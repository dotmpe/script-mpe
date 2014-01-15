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
from txs import Txs


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

class FileInfoApp(Txs):

    NAME = 'mm'
    PROG_NAME = os.path.splitext(os.path.basename(__file__))[0]

#    DB_PATH = os.path.expanduser('~/.fileinfo.db')
#    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

#    TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['file_info']
    #NONTRANSIENT_OPTS = Cmd.NONTRANSIENT_OPTS 
    DEFAULT = ['file_info']

    DEPENDS = {
            'file_info': ['txs_session'],
            'name_and_categorize': ['txs_session'],
            'mm_stats': ['txs_session'],
            'list_mtype': ['txs_session'],
            'list_mformat': ['txs_session'],
            'add_genre': ['txs_session'],
            'add_mtype': ['txs_session'],
            'add_mformats': ['txs_session']
        }

    @classmethod
    def get_optspec(Klass, inheritor):
        p = inheritor.get_prefixer(Klass)
        return (
                p(('--file-info',), libcmd.cmddict(help="Default command. ")),
                p(('--name-and-categorize',), libcmd.cmddict(
                    help="Need either --interactive, or --name, --mediatype and "
                        " --mediaformat. Optionally provide one or more --genre's. "
                )),
                p(('--stats',), libcmd.cmddict(help="Print media stats. ")),
                p(('--list-mtype',), libcmd.cmddict(help="List all mediatypes. ")),
                p(('--list-mformat',), libcmd.cmddict(help="List all media formats. ")),
                p(('--add-mtype',), libcmd.cmddict(help="Add a new mediatype. ")),
                p(('--add-mformats',), libcmd.cmddict(help="Add a new media format(s). ")),
                p(('--add-genre',), libcmd.cmddict(help="Add a new media genre. ")),

                p(('--name',), dict(
                    type='str'
                )),
                p(('--mtype',), dict(
                    type='str'
                )),
                p(('--mformat',), dict(
                    type='str'
                )),
                p(('--genres',), dict(
                    action='append',
                    default=[],
                    type='str'
                ))
               # (('-d', '--dbref'), {'default':self.DEFAULT_DB, 'metavar':'DB'}),
            )

    def list_mformat(self, sa):
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

    def add_genre(self, genre, supergenre, opts=None, sa=None):
        log.crit("TODO add genre %s %s", genre, supergenre)

    def add_mtype(self, mtype, label, opts=None, sa=None):
        """
        Add one or more new mediatypes.
        """
        assert mtype, "First argument 'mtype' required. "
        mt = sa.query( Mediatype )\
                .filter( Mediatype.name == mtype )\
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
        yield dict(mtn=mtn)
        yield dict(mt=mt)

    def add_mformats(self, opts=None, sa=None, *formats):
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
            if opts.interactive: # XXX: add_mformats interactive
                mfs = Mediaformat.search(name=fmt)
                print 'TODO', mfs
            mf = Mediaformat( name=fmt, date_added=datetime.now() )
            log.info('New format %s', mf)
            sa.add(mf)
            yield dict(mf=mf)
        sa.commit()

# TODO: adding Mediameta for files
    def name_and_categorize(self, opts=None, sa=None, 
            name=None, mtype=None, mformat=None, genres=None, *paths):
        if len(paths) > 1:
            assert opts.interactive
            for path in paths:
                for subpath in res.fs.Dir.walk(paths, opts):#dict(recurse=True)):
                    print subpath
        elif not opts.interactive:
            path = paths[0]
            mm = Mediameta(name=name)
            if mtype:
                mt = [ ret['mt'] for ret in self.add_mtype( mtype, None, opts=opts, sa=sa )
                        if 'mt' in ret ].pop()
                mm.mediatype = mt
            if mformat:
                mf = [ ret['mf'] for ret in self.add_mformats( opts, sa, mformat )
                        if 'mf' in ret ].pop()
                mm.mediaformat = mf
            if genres:
                mm.genres = [ ret['genre'] 
                        for ret in self.add_genre( genre, None, opts=opts, sa=sa )
                        if 'genre' in ret ]
            sa.add(mm)
            sa.commit()
            log.note("Created media %s", mm)

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

