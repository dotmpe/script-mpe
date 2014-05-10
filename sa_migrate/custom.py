import os
from ConfigParser import ConfigParser

from migrate.versioning.shell import main


def read(env):
    prsr = ConfigParser()
    path = os.path.join("sa_migrate", env, "migrate.cfg")
    assert prsr.read(path) == [path]
    return prsr

def migrate_opts(env, config):
    if env == 'cllct':
        path = os.path.join( os.getcwd(), '.cllct', 'db.sqlite' ), 
    elif env == 'bms':
        path = os.path.join( os.getcwd(), '.cllct', 'bms.sqlite' ), 
    else:
        assert False, env
    return dict(
            url='sqlite:///%s' % path,
            debug='False', 
            repository='sa_migrate/'+env
        )

def main(env):
    config = read(env)
    opts = migrate_opts(env, config)
    dbpath = opts['url'][10:]
    dbdir = os.path.dirname(dbpath)

    import sys
    if len(sys.argv) == 1:
        sys.argv.append('help')

    if sys.argv[1] in ('dbpath',):
        print dbpath
        return

    if sys.argv[1] in ('dbdir',):
        print dbdir
        return

    if sys.argv[1] in ('reset',):
        try:
            os.unlink(dbpath)
        except OSError, e:
            print >>sys.stderr, "No reset:", e

    from migrate.versioning.shell import main
    if sys.argv[1] in ('init', 'reset'):
        if not os.path.exists(dbdir):
            os.makedirs(dbdir)
        sys.argv[1] = 'version_control'
        main(**opts)
        return

    main(**opts)

