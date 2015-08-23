"""enf - another enfilade without name

2014-01-03
----------
An enfilade is a doubly-linked tree.
Specifically, enfilades enable versioning of a single or multi dimensional tree,
where content is broken up into nodes which resemble parts of various versions.
Iow. upon each change to the structure a new structure is built on the previous
one, sharing as much as content leafs as possible.

Enfilade trees are traversed in two directions. 
At some point in de Xanadu project, these where called the 

1. OTree or organizational tree when traversion from the version-root (O-root) to a
content-leaf (O-leaf), and 
2. HTree for history traversal from a content-leaf (H-root) to all versions
(H-leafs) that contain this content piece.

Not sure if I get all the theory, I don't know of much formal literature on it.
XXX Perhaps if I looked for some other keywords.

There is however the claim that enfilade theory was formalized
and usuable for any content not just literature; audio, video, images and more
application specific documents.

Udanax Green [Xu88.1] which still runs builds a docuverse around various
forms of enfilade. There should be/was once some online docs on the ent, 
which is enfilade theory of Udanax Gold I think.

Knowing this (and beyond there is also special address type for this)
these two are the basic concepts enfilades are build arond:

I - invariant streams are tumbler addressed immutable
V - a mutable tumbler address space is the virtual space ie. the document
    (or work, version)

For 1-dimensional (at least I think a single document text enf is 1-dimensional)
there are some basic operations.

widding
    from wid, the varname for a nodes width
disping
    traversing upward the OTree?
    from dsp, the varname for a nodes offset

obviously some smart balancing is needed for the two trees and the solution may
be a bit elusive for me, perhaps Xu88.1 can offer inspiration.
XuGold is harder to read being customized smalltalk.

XXX
    from what i've seen, I do not understand how a content piece 
    that is not broken upon insert can be re-used.

    In Xu Green, there was a lot off different enfilades going on
    to support the various aspects of the docuverse, possilby incuding 
    a I-I mapping of (split)nodes to original, unbroken content spans to manage
    this. 
    Remember, each of these structures needs double linking for to O- and H-tree
    traversal to work.

    I see an option here for predefined ways of sharing content:
    splitting only per char, word, sentence, paragraph or any other span or
    black and only re-using these pieces. Char-sharing is the only
    complete form of content sharing but probably at some overhead
    of which I'm not sure how that develops. Enfilades should be implemented
    with log(n) lookups etc. but still, 
    while not tackling this issuea like Xu, each node will be created on
    instantiation, take up some space, and perhaps be never re-used.
    That can be a lot of nodes for some texts depending on the pre-store
    splitting.

    The parallel stream approach has built-in span addressing and 
    does not do any enfiladics.

TODO Need to revisit older enfiladics, scrow and udanax projects first.
"""


class EnfNode():

    def __init__(self, content):
        """
        Enter content, 
        """

    def append(self, content):
        """
        Create new node, append current and new content, balance, return.
        """

    def split(self, delim):
        """
        Create a new node, of a list type?
        """


class PStream(object):
    """
    parrallel streams, one content and one ore more edit or markup makes an EDL
    this does not build persisted versionable structures but simulates the
    effect thourgh recording effectively an edit session.
    this way, other document content can be expressed too
    """

