#!/usr/bin/env python
"""project -
:created: 2014-02-26
:updated: 2015-06-30
"""
from __future__ import print_function

__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.taxus-code.sqlite'
__usage__ = """

Usage:
  project.py [options] ( find <ref>...
                       | info [ <ref>... ]
                       | init [ -p... ]
                       | list
                       | new -p...
                       | update -p... <ref> )
  project.py [options] db (init|reset|stats) [-y]
  project.py [options] [command]
  project.py -h|--help|help
  project.py --version

TODO: <ref> would be an ID, name or path of a project

Options:
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    -p --props=NAME=VALUE
                  Give additional properties for new records or record updates.
    -y --yes      Force questions asked to yes.
    -v            Increase verbosity.
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __db__, __version__ )
__doc__ += __usage__

import os
import re
from datetime import datetime

import rsr
import libcmd_docopt
import log
from libcmd_docopt import cmd_help
from taxus import ScriptMixin, SqlBase, get_session
from taxus.v0 import Node, Topic, Host, Project, VersionControl
from res import Workdir, Repo


models = [ Project, VersionControl ]


def cmd_db_init(settings):
    """
    Initialize if the database file doest not exists,
    and update schema.
    """
    get_session(settings.dbref)
    SqlBase.metadata.create_all()
    print("Updated schema", settings.dbref)

def cmd_db_reset(settings):
    """
    Drop all tables and recreate schema.
    """
    get_session(settings.dbref)
    if not settings.yes:
        x = input("This will destroy all data? [yN] ")
        if not x or x not in 'Yy':
            return 1
    SqlBase.metadata.drop_all()
    SqlBase.metadata.create_all()
    print("Done", settings.dbref)

def cmd_db_stats(settings):
    """
    Print table record stats.
    """
    sa = get_session(settings.dbref)
    for m in [ Node, Topic, Project, VersionControl, Host ]:
        print(m.__name__+':', sa.query(m).count())
    print("Done", settings.dbref)

def cmd_find(settings):
    """
    Default command. TODO: res.ws.Workdir.
    """
    #sa = get_session(settings.dbref)
    project = Workdir.find()
    print(project)

def cmd_info(settings):
    sa = Project.get_session('default', settings.dbref)
    #sa = get_session(settings.dbref)
    pwd = os.getcwd()
    name = os.path.basename(pwd)
    workdir = Workdir.find(pwd)
    if not workdir:
        log.stderr("Not in a metadata workdir!")
    rs = Project.search(_sa=sa, name=name)
    if not rs:
        log.stderr("No project found for %r" % name)
        return 1
    proj=rs[0]
    try:
        hosts = proj.hosts
    except Exception as e:
        log.stderr(settings.dbref, Project.metadata.bind)
        log.stderr("Error proj.hosts %s", e)
        hosts = []
    log.std(proj.name, hosts, proj.repositories[0].vc_type, proj.date_added)


def cmd_init(settings):
    sa = Workspace.get_session('project', __version__)
    sa = Project.get_session('default', settings.dbref)
    #sa = get_session(settings.dbref)
    pwd = os.getcwd()
    name = os.path.basename(pwd)
    projdir = Workdir.find(pwd)
    rs = Project.search(name=name)
    if projdir:
        if not rs:
        	pass
        log.stderr("Already in existing project!")
        log.stderr(projdir[0])
        return 1
    if rs:
        log.stderr("Project with this name already exists")
        return 1
    projdir = Workdir(pwd)
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
    projdir.init(create=True)
    log.std("Created project", name, projdir.metadir_id)

def cmd_new():
    print('TODO: project-new')

def cmd_update():
    print('TODO: project-update')

def cmd_list(settings):
    sa = Project.get_session('default', settings.dbref)
    for p in sa.query(Project).all():
        print(p)



### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    libcmd_docopt.defaults(opts.flags)
    return init

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = 'info'
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'project.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    opts = libcmd_docopt.get_opts(__doc__, version=get_version(),
            defaults=defaults)
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
