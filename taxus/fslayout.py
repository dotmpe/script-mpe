import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
#from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref

import core
import fs
from util import SessionMixin
from init import SqlBase

"""
Partial tree templates.
"""


# mapping table for FolderLayout *-* FolderLayout
fslayouts_fslayouts = Table('fslayouts_fslayouts', SqlBase.metadata,
    Column('fslayouts_ida', Integer, ForeignKey('fslayouts.id')),
    Column('fslayouts_idb', Integer, ForeignKey('fslayouts.id'))
)

class FolderLayout(core.Node):

    __tablename__ = 'fslayouts'
    __mapper_args__ = {'polymorphic_identity': 'folderlayout'}

    fslayout_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    supernodes = relationship('FolderLayout', 
                secondary=fslayouts_fslayouts,
                secondaryjoin=(
                    fslayouts_fslayouts.c.fslayouts_idb == fslayout_id),
                primaryjoin=(
                    fslayouts_fslayouts.c.fslayouts_ida == fslayout_id),
                backref='subnodes')

    title = Column(String(255))
    description = Column(Text)

    @staticmethod
    def match(sa, other):
        return False

    @staticmethod
    def template_from_folder(node):
        pass

    @staticmethod
    def template_to_folder(sa, node):
        pass

    def from_folder(sa, node):
        pass

    def to_folder(self, node, recurse=True):
        pass


class Folder(core.Node):

    __tablename__ = 'folders'
    __mapper_args__ = {'polymorphic_identity': 'node:folder'}

    folder_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    inode_id = Column(Integer, ForeignKey('inodes.id'))
    inode = relationship(fs.INode, 
            primaryjoin=fs.INode.inode_id == inode_id)

    layout_id = Column(Integer, ForeignKey('fslayouts.id'))
    layout = relationship(FolderLayout, 
                primaryjoin=layout_id==FolderLayout.fslayout_id)

    title = Column(String(255), unique=True)
    description = Column(Text)



"""

- versioned folder
- vcs root folder
- vcs repository

- Home directory
- Download directory
  - Shared Directory
    - Complete
    - Partial
  - Media     
- Documents directory
  - Media     
- Pictures/Photos directory
  - Media     
- Videos/Movies directory
  - Media     
- Music directory
  - Media     

- Media
  - application
  - text
  - audio
    - speech
      - books
      - radio
      - lectures
      - interviews
    - music
      - classical
      - pop/rock
      - electronic
    - fx
  - video
    - education
    - background
    - entertainment
      - series
      - features
      - music
      - cartoons
    - interviews
  - graphic
    - mesh

- Project directory
- Clients directory

- Personal
- Private 



"""



