from metafile import Metadir

# local
import task
import txt


class JournalTxtManifestEntryParser(txt.AbstractTxtRecordParser):
    fields = ("creation_date completion_date").split(" ")
    def __init__(self, raw, **attrs):
        super(JournalTxtManifestEntryParser, self).__init__(raw, **attrs)
        self.tags = list(task.parse_tags(" %s ." % raw))

class JournalTxtManifestParser(txt.AbstractTxtListParser):
    item_parser = JournalTxtManifestEntryParser
    def __init__(self, **kwds):
        super(JournalTxtManifestParser, self).__init__(**kwds)


class Journal(Metadir):

    DOTID = 'journal'


class JournalDir(object):

    DEFAULT_DIR = 'log'

    @classmethod
    def find(class_, path=None):
        if not path:
            path = class_.DEFAULT_DIR
        assert os.path.exists(path), path
        return class_(path)

    def __init__(self, path):
        self.path = path

    def entries(self):
        pass
