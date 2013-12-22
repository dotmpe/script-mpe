"""
- Store path to topic mappings locally, JSON.
- Perhaps temporary name FileMap, FileTopicMap.. etc. See treemap. fstreemap?
  treemap -fs blah..
"""
from taxus import Node



class FileTreeTopic(Node):

    """
    Maintain metadata for TopicTrees from filesystem trees.
    """

    __tablename__ = 'filetrees'
    id = Column(Integer, primary_key=True)

#    nodes = 
#    subNodes = relationship('', secondary=locators_checksum,
#        backref='location')

class FSTopic(Topic):
    pass

class FSTopicTreeFe(libcmd.SimpleCommand):

    """
    Construct Topic trees from file system paths.
    Command line class.
    """

    DEFAULT_ACTION = 'run'

    def get_opts(self):
        return Taxus.get_opts(self) + ()

    def run(self, *args, **opts):
        pass


