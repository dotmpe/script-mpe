

class TNode(core.Node):

    """
    A (structured) text node.
    That is set up to keep some data of on-fs text files.

    Name equals <context> ':' <local-path-name>

    Map to inode by resolving the ntype for <context>.
    """

    title = Column(String(255), index=True, unique=True)

    # tags
    # topics


class JournalEntry(TNode):
    pass


