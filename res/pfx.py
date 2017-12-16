from script_mpe import confparse, lib


class Prefixes(object):

    def __init__(self):
        super(self, Prefixes).__init__()

    def load_prefixes(self):
        out = lib.cmd('htd prefixes table')
        for l in out.split('\n'):
            print(l)

    def list_prefixes(self):
        pass
