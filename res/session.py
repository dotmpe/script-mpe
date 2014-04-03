import metafile 
import fs


class Session(fs.Dir):

    ""

    def __init__(self, path):
        self.path = path

    def fetchAll(self, pwd):
        # find all .cllct metadirs with *.id files?
        # starting at pwd, do bottom-up glob search
        pass # TODO: Dir.walk and glob or filters, see dev_treemap
