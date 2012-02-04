"""
TODO: reinvent rsr using script libs
TODO: where to store settings, data; need split-settings/composite-db
"""
import os

import confparse
from libcmd import Cmd, err
from taxus import Node, INode, get_session


class Rsr(Cmd):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

    TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['query']
    DEFAULT_ACTION = 'list_nodes'
    
    def get_opts(self):
        return Cmd.get_opts(self) + (
                (('-d', '--dbref'), {'default':self.DEFAULT_DB, 'metavar':'DB'}),
                (('-q', '--query'), {'action':'store_true'}),
            )

    def list_nodes(self, *args, **kwds):
        session = get_session(kwds['dbref'])
        print session.query(Node).all()


if __name__ == '__main__':
    app = Rsr()
    app.main()


