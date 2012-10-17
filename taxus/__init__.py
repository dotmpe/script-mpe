#!/usr/bin/env python
"""
Taxus ORM (SQL) model.

All objects inherit from Node. Each object type is has its own table. Stored
objects have records in `nodes` and all other 'parent' tables (references via
foreign-keys). The `nodes` table stores the objects type, meaning there can be 
only one type for a node record at any time.

TODO: redraw this diagram.
Inheritance hierarchy and relations::

                         Node
                          * name:String(255)
                          * type
                          * date-added
                          * deleted
                          * date-deleted

                              A
                              |
           .-------------- .--^-------. ----------. -----. 
           |               |          |            |      |   
          INode            |         Status       Host    |
           * local_path    |          * nr         * hostname 
           * size          |          * http_code         |
           * cum_size      |                              |
           * host          |          ^                   |
                           |          |                   |
                           |          |                   | 
        A                  |          |                   | 
        |                  |          |                   | 
     CachedContent        Resource    |                   |    
      * cid                * status --/                   |        
      * size               * location:Location            | 
      * charset            * last/a/u-time                |  
      * partial            * allowed                      | 
      * expires                                           |
      * etag               A                              |
      * encodings          |                              |
                           |                              | 
      ^                    |                        /--< Description
      |                    |                        |     * namespace:Namespace
      |  Invariant --------'-- Variant              |      
      \-- * content        |    * vary              |     A               
          * mediatype      |    * descriptions >----/     |         
          * languages      |                              '-- Comment       
                           |    A                         |    * node:Node
                           |    |                         |    * comment:Text
                           |    |                         |     
               ChecksumDigest   |   Namespace                  '-- ...
                * sha1     |    * prefix:String           * subject    
                * md5      |                              * predicate   
                           '-- Relocated                  * object     
                           |    * redirect:Location 
                           |    * temporary:Bool
                           |                                                
                           '-- Bookmark                  Formula         
                                                             * statements

    ID 
     * id
     * date-added
     * deleted
     * date-deleted

         A
         |
     .---^------.
     |          |
     |        Name
     |         * id
     |         * name
     |
   Locator   
    * id
    * ref
    * checksum:ChecksumDigest

                                                                                  


This schema will make node become large very quickly. Especially as various
metadata relations between Nodes are recorded in Statements.
In addition, Statements will probably rather refer to Fragment nodes rather than 
Resource nodes, adding another layer of similar but distinct nodes.

The Description column in the diagram is there to get an idea, while most such
data should be stored a suitable triple store.

TODO: move all models to _model module.
"""
import os

from sqlalchemy.orm.exc import NoResultFound

import iface
import util

from init import SqlBase
from util import SessionMixin

import core
import fs
import checksum
import net
import fslayout

from core import *
from net import *
from fs import *
from fslayout import *


class Taxus(object):

    # Extra commands
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
        print "Initialized host:"
        print iface.IFormatted(host).__str__()
        return host

    def init_database(self, options=None):
        dbref = options.dbref
        print "Applying SQL DDL to DB %s " % dbref
        self.session = util.get_session(dbref, initialize=True)
        return self.session

    def find_inode(self, path):
        # FIXME: rwrite to locator?
        inode = INode(local_path=path)
        inode.host = self.find_host()
        return inode

    def query(self, *args, **opts):
        print 'TODO: query:',args
        q = self.session.query(Node)
        return ResultSet(q, q.all())

    subcmd_aliases = {
            'rm': 'remove',
            'upd': 'update',
        }

    def node(self, *args, **opts):
        subcmd = args[0]
        while subcmd in subcmd_aliases:
            subcmd = subcmd_aliases[subcmd]
        assert subcmd in ('add', 'update', 'remove'), subcmd
        getattr(self, subcmd)(args[1:], **opts)
       
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


