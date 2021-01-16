from sqlalchemy import *
from migrate import *



mig_001_meta = MetaData()

mig_001_mig_001_accs = Table('accs', mig_001_meta,
	Column('number', INTEGER, primary_key=True, nullable=False),
	Column('balance', INTEGER),
	Column('name', VARCHAR),
	Column('id', VARCHAR),
	Column('date_added', DATETIME, nullable=False),
	Column('date_updated', DATETIME, nullable=False),
	Column('deleted', BOOLEAN),
	Column('date_deleted', DATETIME),
)

mig_001_bm = Table('bm', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=255)),
	Column('extended', TEXT),
	Column('public', BOOLEAN),
	Column('tags', TEXT),
)

mig_001_ccnt = Table('ccnt', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('cid', VARCHAR(length=255)),
	Column('size', INTEGER, nullable=False),
	Column('charset', VARCHAR(length=32)),
	Column('partial', BOOLEAN),
	Column('etag', VARCHAR(length=255)),
	Column('expires', DATETIME),
	Column('encodings', VARCHAR(length=255)),
)

mig_001_chks = Table('chks', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('date_added', DATETIME, nullable=False),
	Column('deleted', BOOLEAN),
	Column('date_deleted', DATETIME),
	Column('digest_type', VARCHAR(length=50)),
)

mig_001_chks_md5 = Table('chks_md5', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('digest', VARCHAR(length=32), nullable=False),
)

mig_001_chks_sha1 = Table('chks_sha1', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('digest', VARCHAR(length=40), nullable=False),
)

mig_001_comments = Table('comments', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('annotated_node', INTEGER),
	Column('comment', TEXT),
)

mig_001_devices = Table('devices', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_dirs = Table('dirs', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_disks = Table('disks', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_doc_root_element = Table('doc_root_element', mig_001_meta,
	Column('inode_id', INTEGER, primary_key=True, nullable=False),
	Column('lctr_id', INTEGER, primary_key=True, nullable=False),
)

mig_001_docs = Table('docs', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('title_id', INTEGER),
)

mig_001_domains = Table('domains', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_fifos = Table('fifos', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_files = Table('files', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_folders = Table('folders', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('title_id', INTEGER),
)

mig_001_frags = Table('frags', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_groupnode_node = Table('groupnode_node', mig_001_meta,
	Column('groupnode_id', INTEGER, primary_key=True, nullable=False),
	Column('node_id', INTEGER, primary_key=True, nullable=False),
)

mig_001_groupnodes = Table('groupnodes', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('root', BOOLEAN),
)

mig_001_hosts = Table('hosts', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_ids = Table('ids', mig_001_meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('idtype', VARCHAR(length=50), nullable=False),
	Column('global_id', VARCHAR(length=255), nullable=False),
)

mig_001_ids_lctr = Table('ids_lctr', mig_001_meta,
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

mig_001_ids_lctr_localname = Table('ids_lctr_localname', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=255), nullable=False),
)

mig_001_inode_locator = Table('inode_locator', mig_001_meta,
	Column('inode_id', INTEGER, primary_key=True, nullable=False),
	Column('lctr_id', INTEGER, primary_key=True, nullable=False),
)

mig_001_inodes = Table('inodes', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('date_created', DATETIME),
	Column('date_accessed', DATETIME, nullable=False),
	Column('date_modified', DATETIME, nullable=False),
)

mig_001_ivres = Table('ivres', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('content_id', INTEGER),
	Column('language', VARCHAR(length=255)),
	Column('mediatype', VARCHAR(length=255)),
)

mig_001_locators_checksums = Table('locators_checksums', mig_001_meta,
	Column('locators_ida', INTEGER),
	Column('chk_idb', INTEGER),
)

mig_001_locators_tags = Table('locators_tags', mig_001_meta,
	Column('locator_ida', INTEGER),
	Column('tags_idb', INTEGER),
)

mig_001_mounts = Table('mounts', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_muts = Table('muts', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('date', DATETIME, nullable=False),
	Column('from_account_nr', INTEGER, nullable=False),
	Column('to_account_nr', INTEGER, nullable=False),
	Column('category', VARCHAR, nullable=False),
	Column('currency', VARCHAR(length=16), nullable=False),
	Column('description', TEXT),
	Column('amount', FLOAT),
)

mig_001_names = Table('names', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=255), nullable=False),
)

mig_001_names_tag = Table('names_tag', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('label', VARCHAR(length=255)),
	Column('description', TEXT),
)

mig_001_names_tags_stat = Table('names_tags_stat', mig_001_meta,
	Column('tag_id', INTEGER, primary_key=True, nullable=False),
	Column('node_type', VARCHAR(length=36), primary_key=True, nullable=False),
	Column('frequency', INTEGER),
)

mig_001_names_topic = Table('names_topic', mig_001_meta,
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

mig_001_nodes = Table('nodes', mig_001_meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('ntype', VARCHAR(length=36), nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('space_id', INTEGER),
)

mig_001_ns = Table('ns', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_outline_bookmarks = Table('outline_bookmarks', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('description', VARCHAR(length=50), nullable=False),
	Column('href', VARCHAR(length=255)),
)

mig_001_outline_folders = Table('outline_folders', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=50), nullable=False),
)

mig_001_outlines = Table('outlines', mig_001_meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('parent_id', INTEGER),
	Column('ntype', VARCHAR(length=36), nullable=False),
)

mig_001_paths = Table('paths', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('path', VARCHAR(length=500), nullable=False),
)

mig_001_photos = Table('photos', mig_001_meta,
	Column('deleted', BOOLEAN),
	Column('date_added', DATETIME, nullable=False),
	Column('date_deleted', DATETIME),
	Column('date_updated', DATETIME, nullable=False),
	Column('id', VARCHAR, primary_key=True, nullable=False),
)

mig_001_projects = Table('projects', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('name', VARCHAR(length=255), nullable=False),
	Column('date_added', DATETIME, nullable=False),
	Column('deleted', BOOLEAN),
	Column('date_deleted', DATETIME),
)

mig_001_projects_hosts = Table('projects_hosts', mig_001_meta,
	Column('proj_id', INTEGER, primary_key=True, nullable=False),
	Column('host_id', INTEGER, primary_key=True, nullable=False),
)

mig_001_projects_vcs = Table('projects_vcs', mig_001_meta,
	Column('proj_id', INTEGER, primary_key=True, nullable=False),
	Column('vc_id', INTEGER, primary_key=True, nullable=False),
)

mig_001_protocols = Table('protocols', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_rcres = Table('rcres', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('rcres_type_id', INTEGER),
)

mig_001_relocated = Table('relocated', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('refnew_id', INTEGER),
	Column('temporary', BOOLEAN),
)

mig_001_res = Table('res', mig_001_meta,
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

mig_001_schemes = Table('schemes', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_sockets = Table('sockets', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_spaces = Table('spaces', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('classes', VARCHAR(length=255)),
)

mig_001_status = Table('status', mig_001_meta,
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

mig_001_stk = Table('stk', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('value', TEXT(length=65535)),
)

mig_001_symlinks = Table('symlinks', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_tag_context = Table('tag_context', mig_001_meta,
	Column('tag_id', INTEGER, primary_key=True, nullable=False),
	Column('ctx_id', INTEGER, primary_key=True, nullable=False),
	Column('role', VARCHAR(length=32)),
)

mig_001_tagnames = Table('tagnames', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('tag', VARCHAR(length=255), nullable=False),
	Column('short_description', TEXT),
	Column('description', TEXT),
)

mig_001_tagnames_topic = Table('tagnames_topic', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('super_id', INTEGER),
	Column('explanation', TEXT(length=65535)),
	Column('location', BOOLEAN),
	Column('thing', BOOLEAN),
	Column('event', BOOLEAN),
	Column('plural', VARCHAR(length=255)),
)

mig_001_tnodes = Table('tnodes', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_token_locator = Table('token_locator', mig_001_meta,
	Column('left_id', INTEGER, primary_key=True, nullable=False),
	Column('right_id', INTEGER, primary_key=True, nullable=False),
)

mig_001_topic_tag = Table('topic_tag', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('topic_id', INTEGER, primary_key=True, nullable=False),
	Column('tag_id', INTEGER, primary_key=True, nullable=False),
)

mig_001_vcs = Table('vcs', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('vc_type', VARCHAR(length=10), nullable=False),
	Column('host_id', INTEGER, nullable=False),
	Column('path', VARCHAR(length=255), nullable=False),
)

mig_001_volumes = Table('volumes', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
	Column('root_node_id', INTEGER),
)

mig_001_vres = Table('vres', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)

mig_001_workset_locator = Table('workset_locator', mig_001_meta,
	Column('left_id', INTEGER, primary_key=True, nullable=False),
	Column('right_id', INTEGER, primary_key=True, nullable=False),
)

mig_001_ws = Table('ws', mig_001_meta,
	Column('id', INTEGER, primary_key=True, nullable=False),
)



tables = [ mig_001_accs, mig_001_bm, mig_001_ccnt, mig_001_chks, mig_001_chks_md5, mig_001_chks_sha1, mig_001_comments, mig_001_devices, mig_001_dirs, mig_001_disks, mig_001_doc_root_element, mig_001_docs, mig_001_domains, mig_001_fifos, mig_001_files, mig_001_folders, mig_001_frags, mig_001_groupnode_node, mig_001_groupnodes, mig_001_hosts, mig_001_ids, mig_001_ids_lctr, mig_001_ids_lctr_localname, mig_001_inode_locator, mig_001_inodes, mig_001_ivres, mig_001_locators_checksums, mig_001_locators_tags, mig_001_mounts, mig_001_muts, mig_001_names, mig_001_names_tag, mig_001_names_tags_stat, mig_001_names_topic, mig_001_nodes, mig_001_ns, mig_001_outline_bookmarks, mig_001_outline_folders, mig_001_outlines, mig_001_paths, mig_001_photos, mig_001_projects, mig_001_projects_hosts, mig_001_projects_vcs, mig_001_protocols, mig_001_rcres, mig_001_relocated, mig_001_res, mig_001_schemes, mig_001_sockets, mig_001_spaces, mig_001_status, mig_001_stk, mig_001_symlinks, mig_001_tag_context, mig_001_tagnames, mig_001_tagnames_topic, mig_001_tnodes, mig_001_token_locator, mig_001_topic_tag, mig_001_vcs, mig_001_volumes, mig_001_vres, mig_001_workset_locator, mig_001_ws ]

def upgrade(migrate_engine):
	# Upgrade operations go here. Don't create your own engine; bind
	# migrate_engine to your metadata
	mig_001_meta.bind = migrate_engine
	for table in tables:
		if not table.exists():
			table.create()

def downgrade(migrate_engine):
	# Operations to reverse the above upgrade go here.
	mig_001_meta.bind = migrate_engine
	for table in tables:
		if table.exists():
			table.drop()
