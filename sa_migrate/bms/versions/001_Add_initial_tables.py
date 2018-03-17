from sqlalchemy import *
from migrate import *



meta = MetaData()

accs = Table('accs', meta,
	Column('number', INTEGER, primary_key=True, nullable=False),
	Column('balance', INTEGER),
	Column('name', VARCHAR),
	Column('id', VARCHAR),
	Column('date_added', DATETIME, nullable=False),
	Column('date_updated', DATETIME, nullable=False),
	Column('deleted', BOOLEAN),
	Column('date_deleted', DATETIME),
)

bm = Table('bm', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=255)),
	Column('extended', TEXT),
	Column('public', BOOLEAN),
	Column('tags', TEXT),
)

ccnt = Table('ccnt', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('cid', VARCHAR(length=255)),
	Column('size', INTEGER, nullable=False),
	Column('charset', VARCHAR(length=32)),
	Column('partial', BOOLEAN),
	Column('etag', VARCHAR(length=255)),
	Column('expires', DATETIME),
	Column('encodings', VARCHAR(length=255)),
)

chks = Table('chks', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('date_added', DATETIME, nullable=False),
	Column('deleted', BOOLEAN),
	Column('date_deleted', DATETIME),
	Column('digest_type', VARCHAR(length=50)),
)

chks_md5 = Table('chks_md5', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('digest', VARCHAR(length=32), nullable=False),
)

chks_sha1 = Table('chks_sha1', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('digest', VARCHAR(length=40), nullable=False),
)

comments = Table('comments', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('annotated_node', INTEGER),
	Column('comment', TEXT),
)

devices = Table('devices', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

dirs = Table('dirs', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

disks = Table('disks', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

doc_root_element = Table('doc_root_element', meta,
	Column('inode_id', INTEGER, primary_key=True, nullable=False),
	Column('lctr_id', INTEGER, primary_key=True, nullable=False),
)

docs = Table('docs', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('title_id', INTEGER),
)

domains = Table('domains', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

fifos = Table('fifos', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

files = Table('files', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

folders = Table('folders', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('title_id', INTEGER),
)

frags = Table('frags', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

groupnode_node = Table('groupnode_node', meta,
	Column('groupnode_id', INTEGER, primary_key=True, nullable=False),
	Column('node_id', INTEGER, primary_key=True, nullable=False),
)

groupnodes = Table('groupnodes', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('root', BOOLEAN),
)

hosts = Table('hosts', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

ids = Table('ids', meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('idtype', VARCHAR(length=50), nullable=False),
	Column('global_id', VARCHAR(length=255), nullable=False),
)

ids_lctr = Table('ids_lctr', meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('idtype', VARCHAR(length=50), nullable=False),
	Column('ref', TEXT),
	Column('domain_id', INTEGER),
	Column('ref_md5_id', INTEGER),
	Column('ref_sha1_id', INTEGER),
)

ids_lctr_localname = Table('ids_lctr_localname', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=255), nullable=False),
)

inode_locator = Table('inode_locator', meta,
	Column('inode_id', INTEGER, primary_key=True, nullable=False),
	Column('lctr_id', INTEGER, primary_key=True, nullable=False),
)

inodes = Table('inodes', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('date_created', DATETIME),
	Column('date_accessed', DATETIME, nullable=False),
	Column('date_modified', DATETIME, nullable=False),
)

ivres = Table('ivres', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('content_id', INTEGER),
	Column('language', VARCHAR(length=255)),
	Column('mediatype', VARCHAR(length=255)),
)

locators_checksums = Table('locators_checksums', meta,
	Column('locators_ida', INTEGER),
	Column('chk_idb', INTEGER),
)

locators_tags = Table('locators_tags', meta,
	Column('locator_ida', INTEGER),
	Column('tags_idb', INTEGER),
)

mounts = Table('mounts', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

muts = Table('muts', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('date', DATETIME, nullable=False),
	Column('from_account_nr', INTEGER, nullable=False),
	Column('to_account_nr', INTEGER, nullable=False),
	Column('category', VARCHAR, nullable=False),
	Column('currency', VARCHAR(length=16), nullable=False),
	Column('description', TEXT),
	Column('amount', FLOAT),
)

names = Table('names', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=255), nullable=False),
)

names_tag = Table('names_tag', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('label', VARCHAR(length=255)),
	Column('description', TEXT),
)

names_tags_stat = Table('names_tags_stat', meta,
	Column('tag_id', INTEGER, primary_key=True, nullable=False),
	Column('node_type', VARCHAR(length=36), primary_key=True, nullable=False),
	Column('frequency', INTEGER),
)

names_topic = Table('names_topic', meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=255), nullable=False),
	Column('super_id', INTEGER),
	Column('explanation', TEXT(length=65535)),
	Column('location', BOOLEAN),
	Column('thing', BOOLEAN),
	Column('event', BOOLEAN),
	Column('plural', VARCHAR(length=255)),
)

nodes = Table('nodes', meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('ntype', VARCHAR(length=36), nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('space_id', INTEGER),
)

ns = Table('ns', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

outline_bookmarks = Table('outline_bookmarks', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('description', VARCHAR(length=50), nullable=False),
	Column('href', VARCHAR(length=255)),
)

outline_folders = Table('outline_folders', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=50), nullable=False),
)

outlines = Table('outlines', meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('parent_id', INTEGER),
	Column('ntype', VARCHAR(length=36), nullable=False),
)

paths = Table('paths', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('path', VARCHAR(length=500), nullable=False),
)

photos = Table('photos', meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', VARCHAR, primary_key=True, nullable=False),
)

projects = Table('projects', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=255), nullable=False),
	Column('date_added', DATETIME, nullable=False),
	Column('deleted', BOOLEAN),
	Column('date_deleted', DATETIME),
)

projects_hosts = Table('projects_hosts', meta,
	Column('proj_id', INTEGER, primary_key=True, nullable=False),
	Column('host_id', INTEGER, primary_key=True, nullable=False),
)

projects_vcs = Table('projects_vcs', meta,
	Column('proj_id', INTEGER, primary_key=True, nullable=False),
	Column('vc_id', INTEGER, primary_key=True, nullable=False),
)

protocols = Table('protocols', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

rcres = Table('rcres', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('rcres_type_id', INTEGER),
)

relocated = Table('relocated', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('refnew_id', INTEGER),
	Column('temporary', BOOLEAN),
)

res = Table('res', meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('locator_id', INTEGER),
	Column('last_access', DATETIME),
	Column('last_modified', DATETIME),
	Column('last_update', DATETIME),
	Column('status', INTEGER),
	Column('allow', VARCHAR(length=255)),
)

schemes = Table('schemes', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

sockets = Table('sockets', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

spaces = Table('spaces', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('classes', VARCHAR(length=255)),
)

status = Table('status', meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('code', INTEGER),
	Column('phrase', VARCHAR(length=255)),
	Column('description', TEXT(length=65535)),
	Column('ref_id', INTEGER),
)

stk = Table('stk', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('value', TEXT(length=65535)),
)

symlinks = Table('symlinks', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

tag_context = Table('tag_context', meta,
	Column('tag_id', INTEGER, primary_key=True, nullable=False),
	Column('ctx_id', INTEGER, primary_key=True, nullable=False),
	Column('role', VARCHAR(length=32)),
)

tagnames = Table('tagnames', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('tag', VARCHAR(length=255), nullable=False),
	Column('short_description', TEXT),
	Column('description', TEXT),
)

tagnames_topic = Table('tagnames_topic', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('super_id', INTEGER),
	Column('explanation', TEXT(length=65535)),
	Column('location', BOOLEAN),
	Column('thing', BOOLEAN),
	Column('event', BOOLEAN),
	Column('plural', VARCHAR(length=255)),
)

tnodes = Table('tnodes', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

token_locator = Table('token_locator', meta,
	Column('left_id', INTEGER, primary_key=True, nullable=False),
	Column('right_id', INTEGER, primary_key=True, nullable=False),
)

topic_tag = Table('topic_tag', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('topic_id', INTEGER, primary_key=True, nullable=False),
	Column('tag_id', INTEGER, primary_key=True, nullable=False),
)

vcs = Table('vcs', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('vc_type', VARCHAR(length=10), nullable=False),
	Column('host_id', INTEGER, nullable=False),
	Column('path', VARCHAR(length=255), nullable=False),
)

volumes = Table('volumes', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('root_node_id', INTEGER),
)

vres = Table('vres', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

workset_locator = Table('workset_locator', meta,
	Column('left_id', INTEGER, primary_key=True, nullable=False),
	Column('right_id', INTEGER, primary_key=True, nullable=False),
)

ws = Table('ws', meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)



tables = [
		accs, bm, ccnt, chks, chks_md5, chks_sha1, comments, devices, dirs, disks, doc_root_element, docs, domains, fifos, files, folders, frags, groupnode_node, groupnodes, hosts, ids, ids_lctr, ids_lctr_localname, inode_locator, inodes, ivres, locators_checksums, locators_tags, mounts, muts, names, names_tag, names_tags_stat, names_topic, nodes, ns, outline_bookmarks, outline_folders, outlines, paths, photos, projects, projects_hosts, projects_vcs, protocols, rcres, relocated, res, schemes, sockets, spaces, status, stk, symlinks, tag_context, tagnames, tagnames_topic, tnodes, token_locator, topic_tag, vcs, volumes, vres, workset_locator, ws
	]

def upgrade(migrate_engine):
	# Upgrade operations go here. Don't create your own engine; bind
	# migrate_engine to your metadata
	meta.bind = migrate_engine
	for table in tables:
		if not table.exists():
			table.create()

def downgrade(migrate_engine):
	# Operations to reverse the above upgrade go here.
	meta.bind = migrate_engine
	for table in tables:
		if table.exists():
			table.drop()
