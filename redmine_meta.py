#!/usr/bin/env python
__version__ = '0.0.0'
__db__ = 'postgresql+psycopg2://redmine:password@localhost:15432/redmine_production'
__usage__ = """
redmine-meta - Read data from Redmine database.

Usage:
    rdm [options] list

Options:
    -v             Increase verbosity.
    -d REF --dbref=REF
                   SQLAlchemy DB URL [default: %s].
    -y --yes
    -V, --version  Show version (%s).

Dependencies:
  psycopg2
    postgresql-devel (Debian: libpq-dev)
      ..

""" % ( __db__, __version__ )
from script_mpe import util, log
from script_mpe import redmine_schema as rdm
from script_mpe.redmine_schema import get_session




### Program sub-commands

def cmd_list(settings):
    sa = get_session(settings.dbref)
    l = 'Projects'
    v = sa.query(rdm.Project).count()
    log.log('{green}%s{default}: {bwhite}%s{default}', l, v)
    for p in sa.query(rdm.Project).all():
        if p.parent_id:
            print p.id, p.parent_id, p.name
        else:
            print p.id, p.name



### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = ['balance', 'verify']
    return util.run_commands(commands, settings, opts)

def get_version():
    return 'redmine-meta.mpe/%s' % __version__

argument_handlers = {
}

if __name__ == '__main__':

    import sys
    opts = util.get_opts(__usage__, meta=argument_handlers, version=get_version())
    opts.flags.dbref = opts.flags.dbref
    sys.exit(main(opts))

