#!/usr/bin/env python
"""todo - time ordered, grouped tasks

Usage:
  todo.py [options] (find|info)
  todo.py help|-h|--help
  todo.py --version

Options:
    -v            Increase verbosity.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: ~/.vc.sqlite].
    -p --props=NAME=VALUE

Other flags:
    -h --help     Show this screen.
    --version     Show version.

TODO::
    
    (dia. 1)      0..1
                   |  partOf
                   |
               +---------+
       0..1 ---|  Tasks  |--- 0..1
               +---------+
    pre-           |          required
    requisites     | subTasks      for
                  0..n 

- Links only along same level.

"""
from datetime import datetime
import os
import re
import hashlib

from docopt import docopt
import zope.interface
import zope.component

import log
import util
from taxus.util import SessionMixin, get_session

from sqlalchemy import Column, ForeignKey, Integer, String, Boolean, Text, create_engine
from sqlalchemy.orm import Session, relationship, backref,\
                                joinedload_all
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm.collections import attribute_mapped_collection


__version__ = '0.0.0'

SqlBase = declarative_base()

class Task(SqlBase, SessionMixin):

    """
    """

    __tablename__ = 'tasks'

    task_id = Column('id', Integer, primary_key=True)

    title = Column(String(255), unique=True)
    description = Column(Text)

    prerequisite_id = Column(Integer, ForeignKey(task_id))
    requiredFor_id = Column(Integer, ForeignKey(task_id))

    partOf_id = Column(Integer, ForeignKey(task_id))

    subtasks = relationship('Task',
            cascade="all, delete-orphan",
            #backref="partOf",
            primaryjoin=partOf_id == task_id,
            foreign_keys=[task_id],
            backref=backref("partOf", remote_side=partOf_id),
            collection_class=attribute_mapped_collection('title')
        )

    def __init__(self, name, parent=None):
        self.name = name
        self.parent = parent

    def __repr__(self):
        return "TreeNode(name=%r, id=%r, partOf=%r)" % (
                self.name,
                self.id,
                self.partOf_id
            )

    def dump(self, _indent=0):
        return "   " * _indent + repr(self) + \
                "\n" +  "".join([ c.dump(_indent + 1)
                    for c in self.children.values()])

# used by db_sa
models = [ Task ]

def cmd_task_update(settings):
    # title, description
    # prerequisites...
    # requiredFor...
    # partOf
    # subtasks...
    pass


def cmd_find(settings):
    print settings

def cmd_info(settings):
    print settings


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
    return 'budget.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__doc__, version=get_version())
    sys.exit(main(opts))


