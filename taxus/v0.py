"""
Taxus ORM (SQL) model.

All objects inherit from Node. Each object type is has its own table. Stored
objects have records in `nodes` and all other 'parent' tables (references via
foreign-keys). The `nodes` table stores the objects type, meaning there can be
only one (sub)type for a node record at any time.

Futher the main value of Node is a string, 'name' of at most 255 characters ie.
easy to fit in common databases string columns.
This value must be unique.



TODO: redraw this diagram.
::

    Node<INode>
     * id_id:Integer<PrimaryKey>
     * ntype:String<50,NotNull,Polymorphic>
     * name:String<255,Null>
     * date_added:DateTime<Index,NotNull>
     * deleted:Bool<Index,DefaultOff>
     * date_deleted:DateTime<Null>

    ID<IID>
     " A global system identifier.
     * id_id:Integer<PrimaryKey>
     * global_id:String<255,Index,Unique,NotNull>
     * date_added:
     * deleted:
     * date_deleted:
     A
     |
    Locator<IID>
     " A global identifier for retrieval of remote content.
     * ref:String<2048,Index,Unique>
     - scheme:String
     - path:String

to cut down on sparseness, perhaps move ref column to
other dedicated big-string index type like Token.. meh
::

    Name<IID>
     " A local unique identifier.
     * name:String<index,unique>
     A
     |
    Tag<IID>
     " a localName, in at least one namespace
     * namespaces:*Namespace
     A
     |
    Topic<IID>
     * topic_id:Integer<PrimaryKey>
     * about_id:Integer<ForeignKey(tag_id)>
     * thing:Bool
     * explanation:Text
     * plural:String

Names may turn out to be different, or the same.
Different names may be noted as such, ie. given a sense-number using some notation.
Otherwise; names that are the same, can be aggregated into the same node where possible.
Ie. in this case Tags that are the same are merged by combining their lists of namespaces
onto one node record.
That may not always be feasible.
Their sense should be the same too.
Lets hope it finds clarity and not raise semantics.

Older diagram follows.

Inheritance hierarchy and relations::

                         Node:Node
                          * id:Integer
                          * ntype:<polymorphic-ID>
                          * name:String(255)
                          * date-added
                          * deleted
                          * date-deleted

                              A
                              |
        .---- .----------- .--^-------. ----------. -----.
        |     |            |          |            |      |
        |    Token         |          |            |      |
        |     * value      |          |            |      |
        |     * refs       |          |            |      |
        |                  |          |            |      |
       INode:Node          |         Status       Host    |
        * local_path:255   |          * nr         * hostname
        * size             |          * http_code         |
        * cum_size         |                              |
        * host:Host        |          ^                   |
                           |          |                   |
          A                |          |                   |
          |                |          |                   |
       CachedContent      Resource    |                   |
        * cid              * status --/                   |
        * size             * location:Location            |
        * charset          * last/a/u-time                |
        * partial          * allowed                      |
        * expires                                         |
        * etag             A                              |
        * encodings        |                              |
                           |                              |
        ^                  |                        /--< Description
        |                  |                        |     * namespace:Namespace
        |  Invariant ------'-- Variant              |
        \-- * content      |    * vary              |     A
            * mediatype    |    * descriptions >----/     |
            * languages    |                              '-- Comment
                           |    A                         |    * node:Node
                           |    |                         |    * comment:Text
                           |    |                         |
                           |   Namespace                  '-- ...
                           |    * prefix:String           * subject
                           |                              * predicate
                           '-- Relocated                  * object
                           |    * redirect:Location
                           |    * temporary:Bool
                           |
                           '-- Bookmark                  Formula
                                                          * statements
                           '-- Volume
                           '-- Workset

          ChecksumDigest
           * date_added
           * date_/deleted
           A
           |
     .-----^------.
     |            |
    SHA1Digest   MD5Digest
     * digest     * digest

    ID
     * id:Integer
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
    * checksums


This schema will make node become large very quickly. Especially as various
metadata relations between Nodes are recorded in Statements.
In addition, Statements will probably rather refer to Fragment nodes rather than
Resource nodes, adding another layer of similar but distinct nodes.

The Description column in the diagram is there to get an idea, while most such
data should be stored a suitable triple store.
"""

# Set SqlBase/metadata

# Local: model
from . import core
from . import fs
from . import checksum
from . import fslayout
from . import hier
from . import generic
from . import net
from . import ns
from . import web
from . import fslayout
from . import semweb
from . import model
from . import htd
from . import code
from . import ledger

from .core import *
from .fs import *
from .hier import *
from .net import *
from .ns import *
from .web import *
from .fslayout import *
from .model import Relocated, Volume, Bookmark
from .htd import TNode, JournalEntry
from .code import *
from .ledger import *



models = \
    core.models + \
    fs.models + \
    checksum.models + \
    fslayout.models + \
    hier.models + \
    generic.models + \
    net.models + \
    ns.models + \
    web.models + \
    fslayout.models + \
    semweb.models + \
    model.models + \
    htd.models + \
    code.models + \
    ledger.models
