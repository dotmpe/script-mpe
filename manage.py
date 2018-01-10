#!/usr/bin/env python
from migrate.versioning.shell import main

if __name__ == '__main__':
#    import os
#    pathdir = os.getcwd()
    main(debug='False')
#    main(url='sqlite:///%s' % os.path.join( pathdir, '.cllct/db.sqlite' ),
#            debug='False', repository='sa_migrate/cllct')
