"""
Schema diffs:
  table with differences: folders
	database missing these columns: is_rootfolder, superfolder_id
  table with differences: names_tags_stat
	model missing these columns: node_type
  table with differences: res
	database missing these columns: first_access, http_status
  table with differences: tagnames_topic
	model missing these columns: event, explanation, location, plural, super_id, thing
	database missing these columns: is_rootnode, supernode_id
"""
from sqlalchemy import *
from sqlalchemy.orm import sessionmaker
from migrate import *

from script_mpe import taxus
from script_mpe.taxus import core

meta = MetaData()

def drop_if_empty(meta, tables):
	sa = sessionmaker(bind=meta.bind)()
	for t in tables:
		T = Table(t, meta, autoload=True)
		if not sa.query(T).all():
			T.drop()
			print('dropped', t)

def create_column(t, col):
	if ( '%s_rev002' % col.name ) in t.c:
		t.c['%s_rev002' % col.name].alter(name=col.name)
	else:
		col.create(t)

def drop_column(t, col):
	t.c[col.name].alter(name='%s_rev002' % col.name)


tables = [
		]

def upgrade(migrate_engine):
	# Upgrade operations go here. Don't create your own engine; bind
	# migrate_engine to your metadata
	meta.bind = migrate_engine

	#missing_from_model = "groupnode_node, groupnodes, names_tag, names_topic, photos, topic_tag".split(", ")
	#drop_if_empty(meta, missing_from_model)

	# Add Adjacency list columns to folders table
	t = Table('folders', meta, autoload=True)
	create_column(t, Column('superfolder_id', Integer, ForeignKey('folders.id')))
	create_column(t, Column('is_rootfolder', Boolean))
	return

	t = Table('folders', meta,
			Column('id', INTEGER, primary_key=True, nullable=False),
			Column('superfolder_id', Integer, ForeignKey('folders.id')),
			Column('is_rootfolder', Boolean)
		)
	t.c.superfolder_id.create(t, populate_default=True)

	t = Table('folders', meta,
			Column('is_rootfolder', Boolean),
			extend_existing=True
		)
	t.c.is_rootfolder.create(t, populate_default=True)

	#t = Table('names_tags_stat', meta, autoload=True)
	#t = Table('res', meta, autoload=True)
	#t = Table('tagnames_topic', meta, autoload=True)

	#for table in tables:
	#	t = Table('', meta, autoload=True)
	#	table.rename(table.name+'_rev002')
	#	table.create()

def downgrade(migrate_engine):
	# Operations to reverse the above upgrade go here.
	meta.bind = migrate_engine

	t = Table('folders', meta, autoload=True)
	drop_column(t, Column('superfolder_id', Integer, ForeignKey('folders.id')))
	drop_column(t, Column('is_rootfolder', Boolean))
	return

	#t = Table('folders', meta,
	#		Column('is_rootfolder', Boolean),
	#		autoload=True,
	#		extend_existing=True
	#	)
	#t.c.is_rootfolder.drop(t)

	#for table in tables:
	#	table.rename(table.name+'_rev002')
		#table.drop()
