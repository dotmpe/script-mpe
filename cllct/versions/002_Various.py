"""
  tables missing from model: anodes, folders, fslayouts, fslayouts_fslayouts, ids_chks, ids_chks_md5, ids_chks_sha1, nodes_nodes
  table with differences: inodes
	database missing these columns: host_id
"""

from sqlalchemy import *
from migrate import *

from migrate.changeset import schema
pre_meta = MetaData()
post_meta = MetaData()

anodes = Table('anodes', pre_meta,
	Column('id', Integer, primary_key=True, nullable=False),
	Column('title', String),
	Column('description', Text),
)

folders = Table('folders', pre_meta,
	Column('id', Integer, primary_key=True, nullable=False),
	Column('inode_id', Integer),
	Column('layout_id', Integer),
	Column('title', String),
	Column('description', Text),
)

fslayouts = Table('fslayouts', pre_meta,
	Column('id', Integer, primary_key=True, nullable=False),
	Column('title', String),
	Column('description', Text),
)

fslayouts_fslayouts = Table('fslayouts_fslayouts', pre_meta,
	Column('fslayouts_ida', Integer),
	Column('fslayouts_idb', Integer),
)

ids_chks = Table('ids_chks', pre_meta,
	Column('id', Integer, primary_key=True, nullable=False),
	Column('date_added', DateTime, nullable=False),
	Column('deleted', Boolean),
	Column('date_deleted', DateTime),
	Column('digest_type', String),
)

ids_chks_md5 = Table('ids_chks_md5', pre_meta,
	Column('id', Integer, primary_key=True, nullable=False),
	Column('digest', String, nullable=False),
)

ids_chks_sha1 = Table('ids_chks_sha1', pre_meta,
	Column('id', Integer, primary_key=True, nullable=False),
	Column('digest', String, nullable=False),
)

nodes_nodes = Table('nodes_nodes', pre_meta,
	Column('nodes_ida', Integer, nullable=False),
	Column('nodes_idb', Integer, nullable=False),
	Column('nodes_idc', Integer),
)

inodes = Table('inodes', post_meta,
	Column('id', Integer, primary_key=True, nullable=False),
	Column('local_path', String(length=255)),
	Column('host_id', Integer),
)

nodes_old = Table('nodes', pre_meta,
	Column('id', Integer, primary_key=True, nullable=False),
	Column('type', String),
	Column('name', String),
	Column('date_added', DateTime, nullable=False),
	Column('deleted', Boolean),
	Column('date_deleted', DateTime),
)
nodes_new = Table('nodes', post_meta,
	Column('id', Integer, primary_key=True, nullable=False),
	Column('ntype', String),
	Column('name', String),
	Column('date_added', DateTime, nullable=False),
	Column('deleted', Boolean),
	Column('date_deleted', DateTime),
)


def upgrade(migrate_engine):
	# Upgrade operations go here. Don't create your own engine; bind
	# migrate_engine to your metadata
	pre_meta.bind = migrate_engine
	post_meta.bind = migrate_engine
	pre_meta.tables['anodes'].drop()
	pre_meta.tables['folders'].drop()
	pre_meta.tables['fslayouts'].drop()
	pre_meta.tables['fslayouts_fslayouts'].drop()
	pre_meta.tables['ids_chks'].drop()
	pre_meta.tables['ids_chks_md5'].drop()
	pre_meta.tables['ids_chks_sha1'].drop()
	pre_meta.tables['nodes_nodes'].drop()
	post_meta.tables['inodes'].columns['host_id'].create()
	pre_meta.tables['nodes'].columns['type'].alter(name='ntype')

def downgrade(migrate_engine):
	# Operations to reverse the above upgrade go here.
	pre_meta.bind = migrate_engine
	post_meta.bind = migrate_engine
	pre_meta.tables['anodes'].create()
	pre_meta.tables['folders'].create()
	pre_meta.tables['fslayouts'].create()
	pre_meta.tables['fslayouts_fslayouts'].create()
	pre_meta.tables['ids_chks'].create()
	pre_meta.tables['ids_chks_md5'].create()
	pre_meta.tables['ids_chks_sha1'].create()
	pre_meta.tables['nodes_nodes'].create()
	post_meta.tables['inodes'].columns['host_id'].drop()
	post_meta.tables['nodes'].columns['ntype'].alter(name='type')

