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
  project.py -h|--help|help
  project.py --version

TODO: <ref> would be an ID, name or path of a project

Options:
    -v            Increase verbosity.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: ~/.taxus-code.sqlite].
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

import rsr
import util
from util import cmd_help
from taxus import Node, Topic, Host, Project, VersionControl
from taxus.init import SqlBase, get_session
from res import Projectdir, Repo



__version__ = '0.0.0'


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
    for m in [ Node, Topic, Project, VersionControl, Host ]:
        print m.__name__+':', sa.query(m).count()
    print "Done", settings.dbref

def cmd_find(settings):
    #sa = get_session(settings.dbref)
    project = Projectdir.find()
    print project

def cmd_info(settings):
    sa = get_session(settings.dbref)
    pwd = os.getcwd()
    name = os.path.basename(pwd)
    projdir = Projectdir.find(pwd)
    if not projdir:
        print "Not in a projectdir!"
    rs = sa.query(Project).filter(Project.name == name).all()
    if not rs:
        print "No project found for %r" % name
        return 1
    proj=rs[0]
    print proj.name, proj.hosts, proj.repositories[0].vc_type, proj.date_added

def cmd_init(settings):
    sa = get_session(settings.dbref)
    pwd = os.getcwd()
    name = os.path.basename(pwd)
    projdir = Projectdir.find(pwd)
    if projdir:
        print "Already in existing project!"
        print projdir[0]
        return 1
    rs = sa.query(Project).filter(Project.name == name).all()
    if rs:
        print "Project with this name already exists"
        return 1
    projdir = Projectdir(pwd)
    projdir.init(create=True)
    project = Project(
            name=name,
            date_added=datetime.now(),
        )
    curhost = Host.init(sa=sa) # FIXME returns localhost.
    # TODO project.hosts.append(curhost)
    repo = Repo(pwd)
    checkout = VersionControl(vc_type=repo.rtype, path=pwd, host=curhost)
    sa.add(checkout)
    project.repositories.append( checkout )# TODO: and remotes 
    sa.add(project)
    sa.commit()
    print "Created project", name, projdir.metadir_id

def cmd_new():
    print 'project-new'

def cmd_update():
    print 'project-update'


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags

    # FIXME: share default dbref uri and path, also with other modules
    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'project.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__doc__, version=get_version())
    sys.exit(main(opts))

