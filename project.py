#!/usr/bin/env python
"""
:updated: 2014-08-26

Usage:
  project.py [options] ( find <ref>... 
                       | info [ <ref>... ]
                       | init [ -p... ]
                       | new -p... 
                       | update -p... <ref> )
  project.py [options] db (init|reset|stats) [-y]
  project.py [options] [command]
  project.py help [command]
  project.py -h|--help
  project.py --version

TODO: <ref> would be an ID, name or path of a project

Options:
    -v            Increase verbosity.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: ~/.project.sqlite].
    -p --props=NAME=VALUE
                  Give additional properties for new records or record updates.
    -y --yes      Force questions asked to yes.

Other flags:
    -h --help     Show this screen.
    --version     Show version.

"""
import os
import re
from datetime import datetime

from docopt import docopt

import rsr
import util
from taxus import Node, Topic, Host, Project, VersionControl
from taxus.init import SqlBase, get_session
from res import Projectdir




def cmd_db_init(settings):
    """
    Initialize if the database file doest not exists,
    and update schema.
    """
    get_session(settings.dbref)
    # XXX: update schema..
    SqlBase.metadata.create_all()
    print "Updated schema", settings.dbref

def cmd_db_reset(settings):
    """
    Drop all tables and recreate schema.
    """
    get_session(settings.dbref)
    if not settings.yes:
        x = raw_input("This will destroy all data? [yN] ")
        if not x or x not in 'Yy':
            return 1
    SqlBase.metadata.drop_all()
    SqlBase.metadata.create_all()
    print "Done", settings.dbref

def cmd_db_stats(settings):
    """
    Print table record stats.
    """
    sa = get_session(settings.dbref)
    for m in [ Node, Topic ]:
        print m.__name__, sa.query(m).count()
    print "Done", settings.dbref

def cmd_find(settings):
    #sa = get_session(settings.dbref)
    project = Projectdir.find()
    print project

def cmd_info():
    print 'project-info'

def cmd_init(settings):
    sa = get_session(settings.dbref)
    name = os.path.basename(os.getcwd())
    print 'init', name
    projdir = Projectdir.find()
    if projdir:
        print "Already in existing project!"
        print projdir
        return 1
    rs = sa.query(Project).filter(Project.name == name).all()
    if rs:
        print "Project with this name already exists"
        return 1
    project = Project(
            name=name,
            date_added=datetime.now(),
        )
    # TODO project.hosts.add(curhost)
    # TODO project.repositories.add( checkout)  and remotes 
    sa.add(project)
    sa.commit()
    print "Created project", name

def cmd_new():
    print 'project-new'

def cmd_update():
    print 'project-update'


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    if opts['--version']:
        print 'project/%s' % __version__
        return

    settings = util.get_opt(opts)

    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    return util.run_commands(commands, settings, opts)


if __name__ == '__main__':
    #projects.main()
    import sys
    opts = docopt(__doc__)
    sys.exit(main(opts))


