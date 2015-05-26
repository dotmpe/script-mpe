"""
"""
import os

import lib
import confparse
from libname import Namespace, Name
from libcmdng import Targets, Arguments, Keywords, Options,\
    Target, TargetResolver



NS = Namespace.register(
        prefix='vol',
        uriref='http://project.dotmpe.com/script/#/cmdline.Volume'
    )

Options.register(NS, 
    )



@Target.register(NS, 'find-volume', 'txs:pwd')
def find_volume(opts=None, pwd=None):
    vdb = None
    print list(confparse.find_config_path("git", pwd.location.path))
    for path in confparse.find_config_path("cllct", pwd.location.path):
        vdb = os.path.join(path, 'volume.db')
        if os.path.exists(vdb):
            break
    if not vdb:
        if opts.init:
            pass
    print vdb
    yield vdb


if __name__ == '__main__':

    print Target.instances.keys()
    import txs, cmdline
    print Target.instances.keys()

    TargetResolver().main(['vol:find-volume'])
    #TargetResolver().main(['cmd:options'])

