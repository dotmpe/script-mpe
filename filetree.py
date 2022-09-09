#!/usr/bin/env python
"""
- Store path to topic mappings locally, JSON.
- Perhaps temporary name FileMap, FileTopicMap.. etc. See treemap. fstreemap?
  treemap -fs blah..
"""
from __future__ import print_function

#from script_mpe.libhtd import *
from script_mpe import libcmd


#class FileTreeTopic(Node):
#
#    """
#    Maintain metadata for TopicTrees from filesystem trees.
#    """
#
#    __tablename__ = 'filetrees'
#    id = Column(Integer, primary_key=True)

#    nodes =
#    subNodes = relationship('', secondary=locators_checksum,
#        backref='location')
#
#class FSTopic(Topic):
#    pass


class FSTopicTreeFe(libcmd.StackedCommand):

    """
    Construct Topic trees from file system paths.
    Command line class.
    """

    DEFAULT_ACTION = 'run_fstree'

    @classmethod
    def get_optspec(Klass, inherit):
        return (
                (('--run-fstree',), libcmd.cmddict()),
            )

    DEPENDS = dict(
        run_fstree = ['load_config']
        )

    def run_fstree(self, opts=None):
        print(opts.todict())


if __name__ == '__main__':

    FSTopicTreeFe.main()
