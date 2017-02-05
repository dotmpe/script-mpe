:created: January 2014

Node
- nodeid


(ILocalNodeService name='fs')('/path')
(ILocalNodeService name='taxus')('/path/foo')
(ILocalNodeService name='lind')('/path')

How do these cooperate using a single nodeid, or a variant name using different
schemes.

TreeNodeDict   res.fs.Dir      taxus.fs.Dir      
somedir        /path/somedir   taxus:/path/somedir


Or perhaps:

TreeNodeDict   res.fs.Dir      taxus.fs.Dir          res.meta.Metadir
somedir        /path/somedir   taxus:/path/somedir   metadir:somedir/.metadir


ITreeNode stores into some service?
Ie. a hiername service extending a unique local name service.
It can get its name from res.fs.Dir, 
iow using ILocalNodeService;name=fs it can get INode type instances and use that in other structures
If it is worth storing it may end up in the taxus: scheme too.
Or some scheme named after the DB id.
And metadir may identify itself with somedir too.

Path names are standardized.
So is it responsible to consider only their name as ID and consequently all instances as the same.

Better not do that just yet.

My current argument is that names on ones local system denote a unique usage, semantics if you will but I will not go there.

But it does present the problem that 'berend' is a name of a user home folder
and a login name, a group name, perhaps an some alias in the URL for a user HTML folder, 

The experiment now is to store the names as Node subtype into taxus.
Container is the first major subtype.

Iow:

    name == taxus:name

FIXME but there is not ILocalNodeService for taxus yet
FIXME and nodeid and name is confused in interfaces


Conceptually::
    
    MyList:NodeContainer
        - MyItem:Tag
        - MyItem2:INode

Lets say I create then Dir MyList--that should be compatible a bit.
Some fe will need to run updates now.
I think rsr should then do some kind of sync or persist of the taxus structure
to fs.

Summing up, some migrations between these local node services:

- Sync fs tree to generic node composite structure.
- Sync node composite structure to taxus persisted structures.
- Sync generic or taxus tree to fs.

That is where I try to get using current interfaces.

There are some variant composites structures for the generic tree though.

Currently I plan to put each of the instances together at different keys in the
TreeNodeDict. The nodename itself can point to a plain list of subnodes.

Ie. TreeNode can store types, classes or interfaces as its keys to refer to
variant objects of the treenode::

   <res.primitive.TreeNode <name>>
        <name>: [ <subnode> ]
        @<attrname>: <refname or value>
        <class 'taxus.fs.Dir'>: <taxus.fs.Dir /path/element/<name>>
        <Interface Metadir>: <res.meta.Metadir <name>/.mymeta>
        <Interface GroupNode>: <taxus.GroupNode <name>>

This kind of base composite should allow some crazy stuff. 
I guess this means TreeNode should do some dynamic lookup for interface queries.
Or better to keep different types apart, use another composite for parallel trees?

Also starting some named utilities providing ILocalNodeService to fetch/init
var. types.



