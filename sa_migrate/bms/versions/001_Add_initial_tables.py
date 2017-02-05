"""
:created: 2014-05-10

"""
from sqlalchemy import *
from migrate import *
from bookmarks_model import SqlBase


tables = [ 
		SqlBase.metadata.tables[table]
		for table in SqlBase.metadata.tables
	]

def upgrade(migrate_engine):
	# Upgrade operations go here. Don't create your own engine; bind
	# migrate_engine to your metadata
	SqlBase.metadata.bind = migrate_engine
	for table in tables:
		table.create()


def downgrade(migrate_engine):
	# Operations to reverse the above upgrade go here.
	SqlBase.metadata.bind = migrate_engine
	for table in tables:
		table.drop()



