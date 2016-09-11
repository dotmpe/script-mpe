
from sqlalchemy import BigInteger, Boolean, Column, Date, DateTime, Float, \
        Index, Integer, LargeBinary, String, Table, Text, text

from sqlalchemy.ext.declarative import declarative_base

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker



class_registry = {}
SqlBase = declarative_base(class_registry=class_registry)
metadata = SqlBase.metadata



def get_session(dbref, initialize=False, metadata=SqlBase.metadata):
    engine = create_engine(dbref)#, encoding='utf8')
    #engine.raw_connection().connection.text_factory = unicode
    metadata.bind = engine
    if initialize:
        log.info("Applying SQL DDL to DB %s..", dbref)
        metadata.create_all()  # issue DDL create
        log.note('Updated schema for %s to %s', dbref, 'X')
    session = sessionmaker(bind=engine)()
    return session



### ORM Schema (generated with sqlacodegen)


class AgileColor(SqlBase):
    __tablename__ = 'agile_colors'

    id = Column(Integer, primary_key=True, server_default=text("nextval('agile_colors_id_seq'::regclass)"))
    container_id = Column(Integer, index=True)
    container_type = Column(String, index=True)
    color = Column(String)


class AgileDatum(SqlBase):
    __tablename__ = 'agile_data'

    id = Column(Integer, primary_key=True, server_default=text("nextval('agile_data_id_seq'::regclass)"))
    issue_id = Column(Integer, index=True)
    position = Column(Integer, index=True)
    story_points = Column(Integer)


class Attachment(SqlBase):
    __tablename__ = 'attachments'
    __table_args__ = (
        Index('index_attachments_on_container_id_and_container_type', 'container_id', 'container_type'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('attachments_id_seq'::regclass)"))
    container_id = Column(Integer)
    container_type = Column(String(30))
    filename = Column(String, nullable=False, server_default=text("''::character varying"))
    disk_filename = Column(String, nullable=False, server_default=text("''::character varying"))
    filesize = Column(BigInteger, nullable=False, server_default=text("0"))
    content_type = Column(String, server_default=text("''::character varying"))
    digest = Column(String(40), nullable=False, server_default=text("''::character varying"))
    downloads = Column(Integer, nullable=False, server_default=text("0"))
    author_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    created_on = Column(DateTime, index=True)
    description = Column(String)
    disk_directory = Column(String)


class AuthSource(SqlBase):
    __tablename__ = 'auth_sources'
    __table_args__ = (
        Index('index_auth_sources_on_id_and_type', 'id', 'type'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('auth_sources_id_seq'::regclass)"))
    type = Column(String(30), nullable=False, server_default=text("''::character varying"))
    name = Column(String(60), nullable=False, server_default=text("''::character varying"))
    host = Column(String(60))
    port = Column(Integer)
    account = Column(String)
    account_password = Column(String, server_default=text("''::character varying"))
    base_dn = Column(String(255))
    attr_login = Column(String(30))
    attr_firstname = Column(String(30))
    attr_lastname = Column(String(30))
    attr_mail = Column(String(30))
    onthefly_register = Column(Boolean, nullable=False, server_default=text("false"))
    tls = Column(Boolean, nullable=False, server_default=text("false"))
    filter = Column(Text)
    timeout = Column(Integer)


class Board(SqlBase):
    __tablename__ = 'boards'

    id = Column(Integer, primary_key=True, server_default=text("nextval('boards_id_seq'::regclass)"))
    project_id = Column(Integer, nullable=False, index=True)
    name = Column(String, nullable=False, server_default=text("''::character varying"))
    description = Column(String)
    position = Column(Integer, server_default=text("1"))
    topics_count = Column(Integer, nullable=False, server_default=text("0"))
    messages_count = Column(Integer, nullable=False, server_default=text("0"))
    last_message_id = Column(Integer, index=True)
    parent_id = Column(Integer)


class Change(SqlBase):
    __tablename__ = 'changes'

    id = Column(Integer, primary_key=True, server_default=text("nextval('changes_id_seq'::regclass)"))
    changeset_id = Column(Integer, nullable=False, index=True)
    action = Column(String(1), nullable=False, server_default=text("''::character varying"))
    path = Column(Text, nullable=False)
    from_path = Column(Text)
    from_revision = Column(String)
    revision = Column(String)
    branch = Column(String)


t_changeset_parents = Table(
    'changeset_parents', metadata,
    Column('changeset_id', Integer, nullable=False, index=True),
    Column('parent_id', Integer, nullable=False, index=True)
)


class Changeset(SqlBase):
    __tablename__ = 'changesets'
    __table_args__ = (
        Index('changesets_repos_rev', 'repository_id', 'revision', unique=True),
        Index('changesets_repos_scmid', 'repository_id', 'scmid')
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('changesets_id_seq'::regclass)"))
    repository_id = Column(Integer, nullable=False, index=True)
    revision = Column(String, nullable=False)
    committer = Column(String)
    committed_on = Column(DateTime, nullable=False, index=True)
    comments = Column(Text)
    commit_date = Column(Date)
    scmid = Column(String)
    user_id = Column(Integer, index=True)


t_changesets_issues = Table(
    'changesets_issues', metadata,
    Column('changeset_id', Integer, nullable=False),
    Column('issue_id', Integer, nullable=False),
    Index('changesets_issues_ids', 'changeset_id', 'issue_id', unique=True)
)


class Comment(SqlBase):
    __tablename__ = 'comments'
    __table_args__ = (
        Index('index_comments_on_commented_id_and_commented_type', 'commented_id', 'commented_type'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('comments_id_seq'::regclass)"))
    commented_type = Column(String(30), nullable=False, server_default=text("''::character varying"))
    commented_id = Column(Integer, nullable=False, server_default=text("0"))
    author_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    comments = Column(Text)
    created_on = Column(DateTime, nullable=False)
    updated_on = Column(DateTime, nullable=False)


class CustomFieldEnumeration(SqlBase):
    __tablename__ = 'custom_field_enumerations'

    id = Column(Integer, primary_key=True, server_default=text("nextval('custom_field_enumerations_id_seq'::regclass)"))
    custom_field_id = Column(Integer, nullable=False)
    name = Column(String, nullable=False)
    active = Column(Boolean, nullable=False, server_default=text("true"))
    position = Column(Integer, nullable=False, server_default=text("1"))


class CustomField(SqlBase):
    __tablename__ = 'custom_fields'
    __table_args__ = (
        Index('index_custom_fields_on_id_and_type', 'id', 'type'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('custom_fields_id_seq'::regclass)"))
    type = Column(String(30), nullable=False, server_default=text("''::character varying"))
    name = Column(String(30), nullable=False, server_default=text("''::character varying"))
    field_format = Column(String(30), nullable=False, server_default=text("''::character varying"))
    possible_values = Column(Text)
    regexp = Column(String, server_default=text("''::character varying"))
    min_length = Column(Integer)
    max_length = Column(Integer)
    is_required = Column(Boolean, nullable=False, server_default=text("false"))
    is_for_all = Column(Boolean, nullable=False, server_default=text("false"))
    is_filter = Column(Boolean, nullable=False, server_default=text("false"))
    position = Column(Integer, server_default=text("1"))
    searchable = Column(Boolean, server_default=text("false"))
    default_value = Column(Text)
    editable = Column(Boolean, server_default=text("true"))
    visible = Column(Boolean, nullable=False, server_default=text("true"))
    multiple = Column(Boolean, server_default=text("false"))
    format_store = Column(Text)
    description = Column(Text)


t_custom_fields_projects = Table(
    'custom_fields_projects', metadata,
    Column('custom_field_id', Integer, nullable=False, server_default=text("0")),
    Column('project_id', Integer, nullable=False, server_default=text("0")),
    Index('index_custom_fields_projects_on_custom_field_id_and_project_id', 'custom_field_id', 'project_id', unique=True)
)


t_custom_fields_roles = Table(
    'custom_fields_roles', metadata,
    Column('custom_field_id', Integer, nullable=False),
    Column('role_id', Integer, nullable=False),
    Index('custom_fields_roles_ids', 'custom_field_id', 'role_id', unique=True)
)


t_custom_fields_trackers = Table(
    'custom_fields_trackers', metadata,
    Column('custom_field_id', Integer, nullable=False, server_default=text("0")),
    Column('tracker_id', Integer, nullable=False, server_default=text("0")),
    Index('index_custom_fields_trackers_on_custom_field_id_and_tracker_id', 'custom_field_id', 'tracker_id', unique=True)
)


class CustomValue(SqlBase):
    __tablename__ = 'custom_values'
    __table_args__ = (
        Index('custom_values_customized', 'customized_type', 'customized_id'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('custom_values_id_seq'::regclass)"))
    customized_type = Column(String(30), nullable=False, server_default=text("''::character varying"))
    customized_id = Column(Integer, nullable=False, server_default=text("0"))
    custom_field_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    value = Column(Text)


class Document(SqlBase):
    __tablename__ = 'documents'

    id = Column(Integer, primary_key=True, server_default=text("nextval('documents_id_seq'::regclass)"))
    project_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    category_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    title = Column(String, nullable=False, server_default=text("''::character varying"))
    description = Column(Text)
    created_on = Column(DateTime, index=True)


class EmailAddress(SqlBase):
    __tablename__ = 'email_addresses'

    id = Column(Integer, primary_key=True, server_default=text("nextval('email_addresses_id_seq'::regclass)"))
    user_id = Column(Integer, nullable=False, index=True)
    address = Column(String, nullable=False)
    is_default = Column(Boolean, nullable=False, server_default=text("false"))
    notify = Column(Boolean, nullable=False, server_default=text("true"))
    created_on = Column(DateTime, nullable=False)
    updated_on = Column(DateTime, nullable=False)


class EnabledModule(SqlBase):
    __tablename__ = 'enabled_modules'

    id = Column(Integer, primary_key=True, server_default=text("nextval('enabled_modules_id_seq'::regclass)"))
    project_id = Column(Integer, index=True)
    name = Column(String, nullable=False)


class Enumeration(SqlBase):
    __tablename__ = 'enumerations'
    __table_args__ = (
        Index('index_enumerations_on_id_and_type', 'id', 'type'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('enumerations_id_seq'::regclass)"))
    name = Column(String(30), nullable=False, server_default=text("''::character varying"))
    position = Column(Integer, server_default=text("1"))
    is_default = Column(Boolean, nullable=False, server_default=text("false"))
    type = Column(String)
    active = Column(Boolean, nullable=False, server_default=text("true"))
    project_id = Column(Integer, index=True)
    parent_id = Column(Integer)
    position_name = Column(String(30))


t_groups_users = Table(
    'groups_users', metadata,
    Column('group_id', Integer, nullable=False),
    Column('user_id', Integer, nullable=False),
    Index('groups_users_ids', 'group_id', 'user_id', unique=True)
)


class ImportItem(SqlBase):
    __tablename__ = 'import_items'

    id = Column(Integer, primary_key=True, server_default=text("nextval('import_items_id_seq'::regclass)"))
    import_id = Column(Integer, nullable=False)
    position = Column(Integer, nullable=False)
    obj_id = Column(Integer)
    message = Column(Text)


class Import(SqlBase):
    __tablename__ = 'imports'

    id = Column(Integer, primary_key=True, server_default=text("nextval('imports_id_seq'::regclass)"))
    type = Column(String)
    user_id = Column(Integer, nullable=False)
    filename = Column(String)
    settings = Column(Text)
    total_items = Column(Integer)
    finished = Column(Boolean, nullable=False, server_default=text("false"))
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)


class IssueCategory(SqlBase):
    __tablename__ = 'issue_categories'

    id = Column(Integer, primary_key=True, server_default=text("nextval('issue_categories_id_seq'::regclass)"))
    project_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    name = Column(String(60), nullable=False, server_default=text("''::character varying"))
    assigned_to_id = Column(Integer, index=True)


class IssueRelation(SqlBase):
    __tablename__ = 'issue_relations'
    __table_args__ = (
        Index('index_issue_relations_on_issue_from_id_and_issue_to_id', 'issue_from_id', 'issue_to_id', unique=True),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('issue_relations_id_seq'::regclass)"))
    issue_from_id = Column(Integer, nullable=False, index=True)
    issue_to_id = Column(Integer, nullable=False, index=True)
    relation_type = Column(String, nullable=False, server_default=text("''::character varying"))
    delay = Column(Integer)


class IssueStatus(SqlBase):
    __tablename__ = 'issue_statuses'

    id = Column(Integer, primary_key=True, server_default=text("nextval('issue_statuses_id_seq'::regclass)"))
    name = Column(String(30), nullable=False, server_default=text("''::character varying"))
    is_closed = Column(Boolean, nullable=False, index=True, server_default=text("false"))
    position = Column(Integer, index=True, server_default=text("1"))
    default_done_ratio = Column(Integer)


class Issue(SqlBase):
    __tablename__ = 'issues'
    __table_args__ = (
        Index('index_issues_on_root_id_and_lft_and_rgt', 'root_id', 'lft', 'rgt'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('issues_id_seq'::regclass)"))
    tracker_id = Column(Integer, nullable=False, index=True)
    project_id = Column(Integer, nullable=False, index=True)
    subject = Column(String, nullable=False, server_default=text("''::character varying"))
    description = Column(Text)
    due_date = Column(Date)
    category_id = Column(Integer, index=True)
    status_id = Column(Integer, nullable=False, index=True)
    assigned_to_id = Column(Integer, index=True)
    priority_id = Column(Integer, nullable=False, index=True)
    fixed_version_id = Column(Integer, index=True)
    author_id = Column(Integer, nullable=False, index=True)
    lock_version = Column(Integer, nullable=False, server_default=text("0"))
    created_on = Column(DateTime, index=True)
    updated_on = Column(DateTime)
    start_date = Column(Date)
    done_ratio = Column(Integer, nullable=False, server_default=text("0"))
    estimated_hours = Column(Float(53))
    parent_id = Column(Integer)
    root_id = Column(Integer)
    lft = Column(Integer)
    rgt = Column(Integer)
    is_private = Column(Boolean, nullable=False, server_default=text("false"))
    closed_on = Column(DateTime)
    sprint_id = Column(Integer, index=True)
    position = Column(Integer, index=True)


class JournalDetail(SqlBase):
    __tablename__ = 'journal_details'

    id = Column(Integer, primary_key=True, server_default=text("nextval('journal_details_id_seq'::regclass)"))
    journal_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    property = Column(String(30), nullable=False, server_default=text("''::character varying"))
    prop_key = Column(String(30), nullable=False, server_default=text("''::character varying"))
    old_value = Column(Text)
    value = Column(Text)


class Journal(SqlBase):
    __tablename__ = 'journals'
    __table_args__ = (
        Index('journals_journalized_id', 'journalized_id', 'journalized_type'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('journals_id_seq'::regclass)"))
    journalized_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    journalized_type = Column(String(30), nullable=False, server_default=text("''::character varying"))
    user_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    notes = Column(Text)
    created_on = Column(DateTime, nullable=False, index=True)
    private_notes = Column(Boolean, nullable=False, server_default=text("false"))


class MemberRole(SqlBase):
    __tablename__ = 'member_roles'

    id = Column(Integer, primary_key=True, server_default=text("nextval('member_roles_id_seq'::regclass)"))
    member_id = Column(Integer, nullable=False, index=True)
    role_id = Column(Integer, nullable=False, index=True)
    inherited_from = Column(Integer)


class Member(SqlBase):
    __tablename__ = 'members'
    __table_args__ = (
        Index('index_members_on_user_id_and_project_id', 'user_id', 'project_id', unique=True),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('members_id_seq'::regclass)"))
    user_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    project_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    created_on = Column(DateTime)
    mail_notification = Column(Boolean, nullable=False, server_default=text("false"))


class Message(SqlBase):
    __tablename__ = 'messages'

    id = Column(Integer, primary_key=True, server_default=text("nextval('messages_id_seq'::regclass)"))
    board_id = Column(Integer, nullable=False, index=True)
    parent_id = Column(Integer, index=True)
    subject = Column(String, nullable=False, server_default=text("''::character varying"))
    content = Column(Text)
    author_id = Column(Integer, index=True)
    replies_count = Column(Integer, nullable=False, server_default=text("0"))
    last_reply_id = Column(Integer, index=True)
    created_on = Column(DateTime, nullable=False, index=True)
    updated_on = Column(DateTime, nullable=False)
    locked = Column(Boolean, server_default=text("false"))
    sticky = Column(Integer, server_default=text("0"))


class News(SqlBase):
    __tablename__ = 'news'

    id = Column(Integer, primary_key=True, server_default=text("nextval('news_id_seq'::regclass)"))
    project_id = Column(Integer, index=True)
    title = Column(String(60), nullable=False, server_default=text("''::character varying"))
    summary = Column(String(255), server_default=text("''::character varying"))
    description = Column(Text)
    author_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    created_on = Column(DateTime, index=True)
    comments_count = Column(Integer, nullable=False, server_default=text("0"))


class OpenIdAuthenticationAssociation(SqlBase):
    __tablename__ = 'open_id_authentication_associations'

    id = Column(Integer, primary_key=True, server_default=text("nextval('open_id_authentication_associations_id_seq'::regclass)"))
    issued = Column(Integer)
    lifetime = Column(Integer)
    handle = Column(String)
    assoc_type = Column(String)
    server_url = Column(LargeBinary)
    secret = Column(LargeBinary)


class OpenIdAuthenticationNonce(SqlBase):
    __tablename__ = 'open_id_authentication_nonces'

    id = Column(Integer, primary_key=True, server_default=text("nextval('open_id_authentication_nonces_id_seq'::regclass)"))
    timestamp = Column(Integer, nullable=False)
    server_url = Column(String)
    salt = Column(String, nullable=False)


class PendingEffort(SqlBase):
    __tablename__ = 'pending_efforts'

    id = Column(Integer, primary_key=True, server_default=text("nextval('pending_efforts_id_seq'::regclass)"))
    issue_id = Column(Integer, nullable=False, index=True)
    date = Column(Date, nullable=False, index=True)
    effort = Column(Float(53))


class Project(SqlBase):
    __tablename__ = 'projects'

    id = Column(Integer, primary_key=True, server_default=text("nextval('projects_id_seq'::regclass)"))
    name = Column(String, nullable=False, server_default=text("''::character varying"))
    description = Column(Text)
    homepage = Column(String, server_default=text("''::character varying"))
    is_public = Column(Boolean, nullable=False, server_default=text("true"))
    parent_id = Column(Integer)
    created_on = Column(DateTime)
    updated_on = Column(DateTime)
    identifier = Column(String)
    status = Column(Integer, nullable=False, server_default=text("1"))
    lft = Column(Integer, index=True)
    rgt = Column(Integer, index=True)
    inherit_members = Column(Boolean, nullable=False, server_default=text("false"))
    default_version_id = Column(Integer)
    product_backlog_id = Column(Integer, index=True)


t_projects_trackers = Table(
    'projects_trackers', metadata,
    Column('project_id', Integer, nullable=False, index=True, server_default=text("0")),
    Column('tracker_id', Integer, nullable=False, server_default=text("0")),
    Index('projects_trackers_unique', 'project_id', 'tracker_id', unique=True)
)


class Query(SqlBase):
    __tablename__ = 'queries'

    id = Column(Integer, primary_key=True, server_default=text("nextval('queries_id_seq'::regclass)"))
    project_id = Column(Integer, index=True)
    name = Column(String, nullable=False, server_default=text("''::character varying"))
    filters = Column(Text)
    user_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    column_names = Column(Text)
    sort_criteria = Column(Text)
    group_by = Column(String)
    type = Column(String)
    visibility = Column(Integer, server_default=text("0"))
    options = Column(Text)


t_queries_roles = Table(
    'queries_roles', metadata,
    Column('query_id', Integer, nullable=False),
    Column('role_id', Integer, nullable=False),
    Index('queries_roles_ids', 'query_id', 'role_id', unique=True)
)


class Repository(SqlBase):
    __tablename__ = 'repositories'

    id = Column(Integer, primary_key=True, server_default=text("nextval('repositories_id_seq'::regclass)"))
    project_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    url = Column(String, nullable=False, server_default=text("''::character varying"))
    login = Column(String(60), server_default=text("''::character varying"))
    password = Column(String, server_default=text("''::character varying"))
    root_url = Column(String(255), server_default=text("''::character varying"))
    type = Column(String)
    path_encoding = Column(String(64))
    log_encoding = Column(String(64))
    extra_info = Column(Text)
    identifier = Column(String)
    is_default = Column(Boolean, server_default=text("false"))
    created_on = Column(DateTime)


class Role(SqlBase):
    __tablename__ = 'roles'

    id = Column(Integer, primary_key=True, server_default=text("nextval('roles_id_seq'::regclass)"))
    name = Column(String(30), nullable=False, server_default=text("''::character varying"))
    position = Column(Integer, server_default=text("1"))
    assignable = Column(Boolean, server_default=text("true"))
    builtin = Column(Integer, nullable=False, server_default=text("0"))
    permissions = Column(Text)
    issues_visibility = Column(String(30), nullable=False, server_default=text("'default'::character varying"))
    users_visibility = Column(String(30), nullable=False, server_default=text("'all'::character varying"))
    time_entries_visibility = Column(String(30), nullable=False, server_default=text("'all'::character varying"))
    all_roles_managed = Column(Boolean, nullable=False, server_default=text("true"))


t_roles_managed_roles = Table(
    'roles_managed_roles', metadata,
    Column('role_id', Integer, nullable=False),
    Column('managed_role_id', Integer, nullable=False),
    Index('index_roles_managed_roles_on_role_id_and_managed_role_id', 'role_id', 'managed_role_id', unique=True)
)


t_schema_migrations = Table(
    'schema_migrations', metadata,
    Column('version', String, nullable=False, unique=True)
)


class Setting(SqlBase):
    __tablename__ = 'settings'

    id = Column(Integer, primary_key=True, server_default=text("nextval('settings_id_seq'::regclass)"))
    name = Column(String(255), nullable=False, index=True, server_default=text("''::character varying"))
    value = Column(Text)
    updated_on = Column(DateTime)


class SprintEffort(SqlBase):
    __tablename__ = 'sprint_efforts'

    id = Column(Integer, primary_key=True, server_default=text("nextval('sprint_efforts_id_seq'::regclass)"))
    sprint_id = Column(Integer, nullable=False, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    date = Column(Date, nullable=False, index=True)
    effort = Column(Float(53))


class Sprint(SqlBase):
    __tablename__ = 'sprints'

    id = Column(Integer, primary_key=True, server_default=text("nextval('sprints_id_seq'::regclass)"))
    name = Column(String, nullable=False, index=True)
    description = Column(Text)
    sprint_start_date = Column(Date, nullable=False)
    sprint_end_date = Column(Date, nullable=False)
    user_id = Column(Integer, nullable=False, index=True)
    project_id = Column(Integer, nullable=False, index=True)
    created_on = Column(DateTime)
    updated_on = Column(DateTime)
    is_product_backlog = Column(Boolean, index=True, server_default=text("false"))
    status = Column(String(10), index=True, server_default=text("'open'::character varying"))


class TimeEntry(SqlBase):
    __tablename__ = 'time_entries'

    id = Column(Integer, primary_key=True, server_default=text("nextval('time_entries_id_seq'::regclass)"))
    project_id = Column(Integer, nullable=False, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    issue_id = Column(Integer, index=True)
    hours = Column(Float(53), nullable=False)
    comments = Column(String(1024))
    activity_id = Column(Integer, nullable=False, index=True)
    spent_on = Column(Date, nullable=False)
    tyear = Column(Integer, nullable=False)
    tmonth = Column(Integer, nullable=False)
    tweek = Column(Integer, nullable=False)
    created_on = Column(DateTime, nullable=False, index=True)
    updated_on = Column(DateTime, nullable=False)


class Token(SqlBase):
    __tablename__ = 'tokens'

    id = Column(Integer, primary_key=True, server_default=text("nextval('tokens_id_seq'::regclass)"))
    user_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    action = Column(String(30), nullable=False, server_default=text("''::character varying"))
    value = Column(String(40), nullable=False, unique=True, server_default=text("''::character varying"))
    created_on = Column(DateTime, nullable=False)
    updated_on = Column(DateTime)


class Tracker(SqlBase):
    __tablename__ = 'trackers'

    id = Column(Integer, primary_key=True, server_default=text("nextval('trackers_id_seq'::regclass)"))
    name = Column(String(30), nullable=False, server_default=text("''::character varying"))
    is_in_chlog = Column(Boolean, nullable=False, server_default=text("false"))
    position = Column(Integer, server_default=text("1"))
    is_in_roadmap = Column(Boolean, nullable=False, server_default=text("true"))
    fields_bits = Column(Integer, server_default=text("0"))
    default_status_id = Column(Integer)


class UserPreference(SqlBase):
    __tablename__ = 'user_preferences'

    id = Column(Integer, primary_key=True, server_default=text("nextval('user_preferences_id_seq'::regclass)"))
    user_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    others = Column(Text)
    hide_mail = Column(Boolean, server_default=text("true"))
    time_zone = Column(String)


class User(SqlBase):
    __tablename__ = 'users'
    __table_args__ = (
        Index('index_users_on_id_and_type', 'id', 'type'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('users_id_seq'::regclass)"))
    login = Column(String, nullable=False, server_default=text("''::character varying"))
    hashed_password = Column(String(40), nullable=False, server_default=text("''::character varying"))
    firstname = Column(String(30), nullable=False, server_default=text("''::character varying"))
    lastname = Column(String(255), nullable=False, server_default=text("''::character varying"))
    admin = Column(Boolean, nullable=False, server_default=text("false"))
    status = Column(Integer, nullable=False, server_default=text("1"))
    last_login_on = Column(DateTime)
    language = Column(String(5), server_default=text("''::character varying"))
    auth_source_id = Column(Integer, index=True)
    created_on = Column(DateTime)
    updated_on = Column(DateTime)
    type = Column(String, index=True)
    identity_url = Column(String)
    mail_notification = Column(String, nullable=False, server_default=text("''::character varying"))
    salt = Column(String(64))
    must_change_passwd = Column(Boolean, nullable=False, server_default=text("false"))
    passwd_changed_on = Column(DateTime)


class Version(SqlBase):
    __tablename__ = 'versions'

    id = Column(Integer, primary_key=True, server_default=text("nextval('versions_id_seq'::regclass)"))
    project_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    name = Column(String, nullable=False, server_default=text("''::character varying"))
    description = Column(String, server_default=text("''::character varying"))
    effective_date = Column(Date)
    created_on = Column(DateTime)
    updated_on = Column(DateTime)
    wiki_page_title = Column(String)
    status = Column(String, server_default=text("'open'::character varying"))
    sharing = Column(String, nullable=False, index=True, server_default=text("'none'::character varying"))


class Watcher(SqlBase):
    __tablename__ = 'watchers'
    __table_args__ = (
        Index('index_watchers_on_watchable_id_and_watchable_type', 'watchable_id', 'watchable_type'),
        Index('watchers_user_id_type', 'user_id', 'watchable_type')
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('watchers_id_seq'::regclass)"))
    watchable_type = Column(String, nullable=False, server_default=text("''::character varying"))
    watchable_id = Column(Integer, nullable=False, server_default=text("0"))
    user_id = Column(Integer, index=True)


class WikiContentVersion(SqlBase):
    __tablename__ = 'wiki_content_versions'

    id = Column(Integer, primary_key=True, server_default=text("nextval('wiki_content_versions_id_seq'::regclass)"))
    wiki_content_id = Column(Integer, nullable=False, index=True)
    page_id = Column(Integer, nullable=False)
    author_id = Column(Integer)
    data = Column(LargeBinary)
    compression = Column(String(6), server_default=text("''::character varying"))
    comments = Column(String(1024), server_default=text("''::character varying"))
    updated_on = Column(DateTime, nullable=False, index=True)
    version = Column(Integer, nullable=False)


class WikiContent(SqlBase):
    __tablename__ = 'wiki_contents'

    id = Column(Integer, primary_key=True, server_default=text("nextval('wiki_contents_id_seq'::regclass)"))
    page_id = Column(Integer, nullable=False, index=True)
    author_id = Column(Integer, index=True)
    text_ = Column(Text)
    comments = Column(String(1024), server_default=text("''::character varying"))
    updated_on = Column(DateTime, nullable=False)
    version = Column(Integer, nullable=False)


class WikiPage(SqlBase):
    __tablename__ = 'wiki_pages'
    __table_args__ = (
        Index('wiki_pages_wiki_id_title', 'wiki_id', 'title'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('wiki_pages_id_seq'::regclass)"))
    wiki_id = Column(Integer, nullable=False, index=True)
    title = Column(String(255), nullable=False)
    created_on = Column(DateTime, nullable=False)
    protected = Column(Boolean, nullable=False, server_default=text("false"))
    parent_id = Column(Integer, index=True)


class WikiRedirect(SqlBase):
    __tablename__ = 'wiki_redirects'
    __table_args__ = (
        Index('wiki_redirects_wiki_id_title', 'wiki_id', 'title'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('wiki_redirects_id_seq'::regclass)"))
    wiki_id = Column(Integer, nullable=False, index=True)
    title = Column(String)
    redirects_to = Column(String)
    created_on = Column(DateTime, nullable=False)
    redirects_to_wiki_id = Column(Integer, nullable=False)


class Wiki(SqlBase):
    __tablename__ = 'wikis'

    id = Column(Integer, primary_key=True, server_default=text("nextval('wikis_id_seq'::regclass)"))
    project_id = Column(Integer, nullable=False, index=True)
    start_page = Column(String(255), nullable=False)
    status = Column(Integer, nullable=False, server_default=text("1"))


class Workflow(SqlBase):
    __tablename__ = 'workflows'
    __table_args__ = (
        Index('wkfs_role_tracker_old_status', 'role_id', 'tracker_id', 'old_status_id'),
    )

    id = Column(Integer, primary_key=True, server_default=text("nextval('workflows_id_seq'::regclass)"))
    tracker_id = Column(Integer, nullable=False, server_default=text("0"))
    old_status_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    new_status_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    role_id = Column(Integer, nullable=False, index=True, server_default=text("0"))
    assignee = Column(Boolean, nullable=False, server_default=text("false"))
    author = Column(Boolean, nullable=False, server_default=text("false"))
    type = Column(String(30))
    field_name = Column(String(30))
    rule = Column(String(30))

