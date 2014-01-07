#!/usr/bin/env python
from migrate.versioning.shell import main

if __name__ == '__main__':
    import os
    main(url='sqlite:///%s' % os.path.join( os.getcwd(), '.cllct/db.sqlite' ), 
            debug='False', repository='sa_migrate/cllct')

