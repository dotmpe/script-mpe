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



