import os
from .persistence import PersistedMetaObject


class MIMEHeader(PersistedMetaObject):
    headers = None
    def __init__(self):
        super(PersistedMetaObject, self).__init__()
        self.headers = {}
    def parse_data(self, lines):
        key, value = "", ""
        for idx, line in enumerate(lines):
            if not line.strip():
                if value:
                    self.headers[key] = value
                break
            continuation = line[0].isspace()
            if continuation:
                value += line.strip()
            else:
                if value:
                    self.headers[key] = value
                key = line[:p].strip()
                assert key, (idx, line)
                value = line[p+1:].strip()
    #def parse(self, source):
    #    pass
    def write(self, fl):
        if not hasattr(fl, 'write'):
            if not os.path.exists(str(fl)):
                os.mknod(str(fl))
            fl = open(str(fl), 'w+')
        # XXX: writes string only. cannot break maxlength without have knowledge of header
        for key in self.headers.keys():
            value = self.headers[key]
            fl.write("%s: %s\n" % (key, value))
        fl.close()
