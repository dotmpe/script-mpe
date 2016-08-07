from sqlalchemy import *
from migrate import *


def upgrade(migrate_engine):
    meta = MetaData(bind=migrate_engine)

    c = meta.bind.connect()
    #c.execute("CREATE TABLE nodes ( id INTEGER auto_increment );")

    # load some related schema
    #nodes = Table('nodes', meta, autoload=True)
    #ids = Table('ids', meta, autoload=True)
    #spaces = Table('spaces', meta, autoload=True)
    #groupnodes = Table('groupnodes', meta, autoload=True)

    #c = Column('ntype', String(36), default="node")
    #c.create(nodes)

    #c = Column('name', String(255), nullable=False, default="Untitled Node", index=True, unique=True)
    #c.alter(nodes)
    #c.create(nodes, index_name='idx_name', unique_name='unique_name')
    #        default="Untitled Node")

    #nodes_nodes = Table('nodes_nodes', meta, autoload=True)
    #nodes_nodes.drop()

    space_id = Column('space_id', Integer, ForeignKey('spaces.id'))
    space_id.create(nodes)


def downgrade(migrate_engine):
    # Operations to reverse the above upgrade go here.
    pass

