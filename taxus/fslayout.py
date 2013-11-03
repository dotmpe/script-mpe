import zope.interface
from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, Text, \
	ForeignKey, Table, Index, DateTime
#from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref

import core
import fs
from util import SessionMixin
from init import SqlBase

"""
Partial tree templates, see res.fslayout
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

	@classmethod
	def from_trees(Class, fsfolderlayout):
		if fsfolderlayout.is_root:
			for sub, subfl in fsfolderlayout:
				yield Class.from_tree(subfl)
		else:
			yield Class.from_tree(subfl)

	@classmethod
	def from_tree(Class, fsfolderlayout):
		fl = FolderLayout(
					title="%s Directory"%fsfolderlayout.name,
					name=fsfolderlayout.name,
					date_added=datetime.now()
				)

		for sub, subfl in fsfolderlayout:
			fl.subnodes.append(Class.from_tree(subfl))
		return fl

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

	def __repr__(self, i=0):
		pad = '  ' * i
		subs = ''
		i+=1
		for s in self.subnodes:
			subs += s.__repr__(i=i)
		if self.name:
			return "%s%s <%s/>\n  %s" % (pad, self.title, self.name, subs)
		else:
			return "%s (root):\n  %s" % (pad, subs)




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



