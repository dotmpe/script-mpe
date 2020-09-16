#!/usr/bin/env python
"""
Taxus ORM (SQLAlchemy)
"""
from __future__ import print_function
import sys
import os
import socket
from datetime import datetime

import couchdb
from sqlalchemy import MetaData
from sqlalchemy.orm.exc import NoResultFound

from script_mpe import confparse, log, mod
from script_mpe.res import dt, js
from script_mpe.res.ws import AbstractYamlDocs


from . import iface
from iface import registry as reg, gsm
from . import init
from . import util
from . import out


from .init import SqlBase
from .util import SessionMixin, ScriptMixin, ORMMixin, get_session


# TODO: cleanup metadata code, should inherit from and managae multiple
# SqlBase instances for proper schema segmentation, and handle overlap

#SqlBase = declarative_base()

staticmetadata = SqlBase.metadata



class CouchMixin(object):
    def __init__(self, *args, **kwds):
        super(CouchMixin, self).__init__()
        self.couch = None
        self.docs = None
        self.couches = dict()

    def init(self, metadata=None):
        g = self.settings
        if hasattr(g, 'no_db') and g.no_db:
            pass
        if hasattr(g, 'no_couch') and g.no_couch:
            if hasattr(g, 'couch') and g.couch:
                self.couchdocs(g.couch)

    def couchdocs(self, ref):
        self.couch = ref.rsplit('/', 1)
        self.docs = self.load_couch(ref)

    def load_couch(self, ref):
        sref, dbname = ref.rsplit('/', 1)
        if sref not in self.couches:
            self.couches[sref] = dict(
                    server=couchdb.client.Server(sref), db=dict()
                )
        self.couches[sref]['db'][dbname] = self.couches[sref]['server'][dbname]
        return self.couches[sref]['db'][dbname]

    @property
    def couchconn(self):
        return self.couches[self.couch[0]]['server']


def dict_tree_map(data, _type, _map):
    for k in data:
        if isinstance(data[k], datetime):
            data[k] = getattr(data[k], _map)()
        elif isinstance(data[k], dict):
            dict_tree_map(data[k], _type, _map)

class OutputMixin(object):
    def __init__(self, *args, **kwds):
        super(OutputMixin, self).__init__()
        #log.out = out

    def init(self):
        self.output_buffer = []
        #log.out.settings = self.settings

    def note(self, msg, *args, **kwds):
        g = self.settings
        if g.quiet:
            return
        if 'lvl' in kwds:
            if g.verbose < kwds['lvl']:
                return
        if 'num' in kwds:
            if not kwds['num'] or ( kwds['num'] % g.interval ) != 0:
                return
        log.stderr(msg, *args)

    def lines_out(self, rs, tp='node'):
        for r in rs:
            self.out(r, tp=tp)

    def get_renderer(self, name='node'):
        g = self.settings
        tpl_name = '%s.%s' % ( name, g.output_format )
        tpl = out.get_template(tpl_name)
        if tpl:
            return tpl.render
        else:
            return lambda o: o

    def out(self, r, tp='node'):
        g = self.settings ; of = g.output_format
        if isinstance(r, dict):
            d = r
        elif isinstance(r, list):
            for i in r:
                self.out(i, tp)
            return
        else:
            if g.struct_output: d = r.to_struct()
            else: d = r.to_dict()

        if of in ( 'json', 'json-stream' ):
            dict_tree_map(d, datetime, 'isoformat')

        elif of in ('repr',):
            d = repr(d)
        elif of in ('str',):
            d = str(d)

        self.output_buffer.append(d)

    def flush(self):
        g = self.settings ; of = g.output_format

        if of == 'json':
            print(js.dumps(self.output_buffer))

        elif of == 'json-stream':
            for it in self.output_buffer:
                print(js.dumps(it))

        else:
            for it in self.output_buffer:
                print(it)
            # TODO:
            #if g.struct_output:
            #    tpl = out.get_template("%sdoc.%s" % (g.tp, of))
            #else:
            #    tpl = out.get_template("%s.%s" % (g.tp, of))
            #out_ = tpl.render

        self.output_buffer = []

    def __delete__(self):
        super(AbstractOutput, self).__delete__()
        if self.output_buffer:
            self.flush()
        log.stderr("Flushed")


class Taxus(AbstractYamlDocs, OutputMixin, CouchMixin):

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

        self.uname = os.uname()[0]
        self.hostname = socket.gethostname()

        # Use settings object iso. many keyword arguments. Set defaults here.
        g = self.settings = confparse.Values(conf)

        self.session = g.initial_session

        if version: self.load(version)

    def init(self, metadata=None):
        g = self.settings
        #super(Taxus, self).init()
        OutputMixin.init(self)
        CouchMixin.init(self)

        if hasattr(g, 'no_db') and not g.no_db:
            assert g.dbref
            self.session = 'default'
            self.setmetadata(metadata)
            self.init_db(g.dbref)

    def get_yaml(self, p, defaults=None):
        assert os.path.exists(p), p
        if defaults and not os.path.exists(p):
            confparse.yaml_dump(open(p, 'w+'), defaults)
        return p


    # SQL Alchemy

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
        assert isinstance(metadata, MetaData), metadata
        self.metadata_per_session[self.session] = metadata

    def load(self, version, session=DEFAULT_SESSION):
        "Load module's model list"
        module = mod.load_module('%s' % version)
        self.setmodels(module.models)

    def init_db(self, dbref, name=DEFAULT_SESSION):
        "Get connection"
        g = self.settings
        if name not in SessionMixin.sessions:
            if name not in self.metadata_per_session:
                raise Exception("No metadata to initialize %s session" % name)
            SessionMixin.get_session(name, dbref, g.create_on_init,
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

    def get_records(self, klass, _filters=(), **kwds):
        g = self.settings
        if kwds:
            rs = klass.search(_sa=self.sa_session, _session=g.session_name, **kwds)
        else:
            rs = klass.all()
        if not rs:
            self.note("Nothing")
        return rs

    def opts_to_filters(self, klass):
        filters = ()
        g = self.settings
        if g.deleted: filters += ( klass.deleted != True, )
        if g.added: field='date_added'
        else: field='date_updated'
        if g.older_than:
            until = dt.shift('-'+g.older_than)
            filters += klass.before_date( until, field )
        else:
            since = dt.shift('-'+g.max_age)
            filters += klass.after_date( since, field )
        return filters

    # XXX: cleanup old code

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
