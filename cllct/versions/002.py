from sqlalchemy import *
meta = MetaData()




def upgrade(migrate_engine):
	meta.bind = migrate_engine
	for table in []:
		table.create()

def downgrade(migrate_engine):
	meta.bind = migrate_engine
	for table in []:
		table.drop()

