import os
from ConfigParser import ConfigParser

from migrate.versioning.shell import main


def read(repopath):
    path = os.path.join(repopath, "migrate.cfg")
    prsr = ConfigParser()
    x = prsr.read(path)
    assert x == [path], ( "Repo config load failed", repopath, x, path )
    return prsr

def migrate_opts(repopath, config):
    if config.has_option('mpe', 'postgres'):
        url = config.get('mpe', 'postgres')
        return dict(
                url='postgresql+psycopg2:///postgres:mysecretpassword@%s' % url,
                debug='False',
                repository=repopath
            )
    elif config.has_option('mpe', 'mysql'):
        url = config.get('mpe', 'mysql')
        return dict(
                url='mysql+mysqlconnector://%s' % url,
                debug='False',
                repository=repopath
            )
    elif config.has_option('mpe', 'path'):
        path = config.get('mpe', 'path')
        return dict(
                url='sqlite:///%s' % path,
                debug='False',
                repository=repopath
            )
    else:
        name = config.get('db_settings', 'repository_id')
        path = os.path.join( os.getcwd(), '.cllct', name+'.sqlite' )
        config.add_section('mpe')
        config.set('mpe', 'path', path)
        cfgpath = os.path.join(repopath, "migrate.cfg")
        config.write(open(cfgpath, 'w+'))
        return dict(
                url='sqlite:///%s' % path,
                debug='False',
                repository=repopath
            )

def main(env, path=None):
    if not path:
        path = os.path.join("sa_migrate", env)
    config = read(path)
    opts = migrate_opts(path, config)
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

    print 'opts', opts
    #sys.argv.append('--url='+opts['url'])
    main(**opts)
