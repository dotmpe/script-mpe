#!/usr/bin/env python
"""
Taxus ORM (SQLAlchemy)
"""
from __future__ import print_function
import os

from sqlalchemy import MetaData
from sqlalchemy.orm.exc import NoResultFound

from script_mpe import confparse, log, mod
from . import iface
from iface import registry as reg, gsm
from . import init
from . import util

from .init import SqlBase
from .util import SessionMixin, ScriptMixin, ORMMixin, get_session


staticmetadata = SqlBase.metadata


class Taxus(object):

    """
    Helper for list of models and connection.
    """

    DEFAULT_SETTINGS = dict(
            yes=False,
            interactive=True,
            create_on_init=False,
            quiet=False,
            initial_session='default',
            default_session='default',
            drop_all=True
        )
    DEFAULT_SESSION = 'default'


    def __init__(self, version='taxus.v0', conf=DEFAULT_SETTINGS):
        "Create context for models"
        self.metadata_per_session = {}
        self.models_per_session = {}
        super(Taxus, self).__init__()

        # Use settings object iso. many keyword arguments. Set defaults here.
        g = self.settings = confparse.Values(conf)

        self.session = g.initial_session

        if version: self.load(version)

    @property
    def models(self):
        sid = self.session
        models = self.models_per_session[sid]
        if models:
            return models
        return []

    @property
    def metadata(self):
        sid = self.session
        return self.metadata_per_session[sid]

    @property
    def sa_session(self):
        sid = self.session
        return SessionMixin.sessions[sid]

    def __getattribute__(self, name):
        sid = object.__getattribute__(self, 'session')
        models = object.__getattribute__(self, 'models_per_session')
        if sid and sid in models:
            models = models[sid]
            for m in models:
                if name is m.model_name():
                    return m
        return object.__getattribute__(self, name)

    def setmodels(self, models):
        self.models_per_session[self.session] = models

    def setmetadata(self, metadata):
        if not metadata:
            metadata = staticmetadata
        self.metadata_per_session[self.session] = metadata

    def load(self, version, session=DEFAULT_SESSION):
        "Load module's model list"
        module = mod.load_module('%s' % version)
        self.setmodels(module.models)

    def init(self, dbref, name=DEFAULT_SESSION):
        "Get connection"
        g = self.settings
        if name not in ScriptMixin.sessions:
            if name not in self.metadata_per_session:
                raise Exception("No metadata to initialize %s session" % name)
            ScriptMixin.get_session(name, dbref, g.create_on_init,
                    self.metadata_per_session[name])

    def create(self, drop_all=None):
        "Create a tables"
        g = self.settings
        if drop_all is None:
            drop_all = g.drop_all
        if drop_all:
            context.metadata.drop_all()
        self.metadata.create_all()
        if not g.quiet:
            if drop_all:
                log.std("Dropped all tables in metadata, and recreated")
            else:
                log.std("Created DB and Tables")

    def reset_metadata(self, name=DEFAULT_SESSION):
        """
        Reset metadata for current set of models
        XXX: what about secondary tables?
        """
        metadata = MetaData()
        if name in SessionMixin.sessions:
            connection = SessionMixin.sessions[name].connection()
            metadata.bind = connection.engine
        self.metadata_per_session[name] = metadata
        for m in self.models_per_session[name]:
            m.metadata = metadata
        return metadata

    def reset(self):
        "TODO: Re-create DB, prime everything.."
        g = self.settings
        if not g.quiet:
            log.stdout("Tables in schema:"+ ", ".join(self.metadata.tables.keys()))
        if g.interactive:
            if not g.yes:
                x = raw_input("This will destroy all data? [yN] ")
                if not x or x not in 'Yy':
                    return 1
        if g.drop_all:
            self.metadata.drop_all()
        else:
            assert False, "get tables.. drop"
        self.metadata.create_all()
        if not g.quiet:
            log.std("Recreated Tables")

    def reflect(self):
        g = self.settings
        self.reset_metadata()
        self.metadata.reflect()

    # XXX: cleanup old commands
    def init_host(self, options=None):
        """
        Tie Host to current system. Initialize Host if needed.
        """
#        assert self.volumedb, "Must have DB first "
        hostnamestr = util.current_hostname(True, options.interactive)
        assert hostnamestr
        hostname = self.hostname_find([hostnamestr], options)
        if not hostname:
            hostname = Name(name=hostnamestr,
                    date_added=datetime.now())
            hostname.commit()
        assert hostname
        host = self.host_find([hostname], options)
        if not host:
            host = Host(hostname=hostname,
                    date_added=datetime.now())
            host.commit()
        assert host
        print("Initialized host:")
        print(iface.IFormatted(host).__str__())
        return host

    def find_inode(self, path):
        # FIXME: rwrite to locator?
        inode = INode(local_path=path)
        inode.host = self.find_host()
        return inode

    def node_add(self, name, **opts):
        "Don't call this directly from CL. "
        s = util.get_session(opts.get('dbref'))
        node = Node(name=name,
                date_added=datetime.now())
        s.add(node)
        return node

    def node_remove(self, *args, **opts):
        s = util.get_session(opts.get('dbref'))
        pass # TODO: node rm
        return
        node = None#s.query(Node).
        node.deleted = True
        node.date_deleted = datetime.now()
        s.add(node)
        s.commit()
        return node

    def node_update(self, *args, **opts):
        pass # TODO: node update

#    def namespace_add(self, name, prefix, uri, **opts):
#        uriref = Locator(ref=uri)
#        node = Namespace(name=name, prefix=prefix, locator=uriref,
#                date_added=datetime.now())
#        s.add(node)
#        s.commit()
#        return node

#    def description_new(self, name, ns_uri):
#        Description(name=name,
#                date_added=datetime.now())

    def comment_new(self, name, comment, ns, node):
        #NS = self.
        node = Comment( name=name,
                #namespace=NS,
                annotated_node=node,
                comment=comment,
                date_added=datetime.now())
        return node
