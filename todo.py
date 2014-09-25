#!/usr/bin/env python
""":created: 2014-08-31

TODO: interface this with Google tasks
"""
__description__ = "todo - time ordered, grouped tasks"
__version__ = '0.0.0'
__db__ = '~/.todo.sqlite'
__usage__ = """
Usage:
  todo.py [options] info
  todo.py [options] list
  todo.py [options] find <title>
  todo.py [options] (new|update <ID>) <title> [<description> <group>]
  todo.py [options] import|export
  todo.py [options] done <ID>...
  todo.py [options] reopened <ID>...
  todo.py [options] <ID> depends <ID2>
  todo.py [options] <ID> prerequisite <ID2>
  todo.py help
  todo.py -h|--help
  todo.py --version

Options:
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]

Other flags:
    -h --help     Show this usage description. 
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

Model::

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

""" % ( __db__, __version__ )
from datetime import datetime
import os
import re
import hashlib

import log
import util
from taxus import Node
from taxus.util import SessionMixin, get_session

from sqlalchemy import Column, ForeignKey, Integer, String, Boolean, Text, create_engine
from sqlalchemy.orm import Session, relationship, backref,\
                                joinedload_all
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm.collections import attribute_mapped_collection




SqlBase = declarative_base()


class Task(SqlBase, Session):#Node):

    """
    """

    __tablename__ = 'tasks'

    task_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    title = Column(String(255), unique=True)
    description = Column(Text, nullable=True)

    partOf_id = Column(Integer, ForeignKey(task_id))

    subtasks = relationship('Task',
            cascade="all, delete-orphan",
            backref=backref("partOf", remote_side=task_id),
            foreign_keys=[partOf_id],
            #collection_class=attribute_mapped_collection('title')
        )

    prerequisite_id = Column(Integer, ForeignKey(task_id))
    requiredFor_id = Column(Integer, ForeignKey(task_id))

    def __repr__(self):
        return "Task(title=%r, id=%r, partOf=%r)" % (
                self.title,
                self.task_id,
                self.partOf_id
            )

    def dump(self, _indent=0):
        return "   " * _indent + repr(self) + \
                "\n" +  "".join([ c.dump(_indent + 1)
                    for c in self.children.values()])

# used by db_sa
models = [ Task ]


def print_Task(task):
    log.std(
            "{blue}%s{bblack}. {bwhite}%s  {bblack}[{green}%s{bblack}]{default}" % (
                task.task_id,
                task.title, 
                task.partOf and task.partOf.task_id or ''
            )
        )
#    print "\t".join(map(str,(task.task_id, str(task.title),
#        #task.partOf and "%i:%r" %(task.partOf.task_id, task.partOf.title) or ''
#        task.partOf and "partOf:%i" %(task.partOf.task_id, ) or ''
#    )))


def indented_tasks(indent, sa, settings, roots):
    for task in roots:
        print indent,
        print_Task(task)
        indented_tasks(indent+'  ', sa, settings, 
            sa.query(Task).filter(Task.partOf_id == task.task_id).all())


### Commands

def cmd_info(settings):
    """
    """
    from pprint import pformat
    print pformat(settings.todict())

def cmd_list(settings):
    sa = get_session(settings.dbref)
    roots = sa.query(Task).filter(Task.partOf_id == None).all()
    indented_tasks('', sa, settings, roots)

def cmd_find(title, settings):
    sa = get_session(settings.dbref)
    task = Task.find(( Task.title == title, ), sa=sa)
    print task
    print_Task(task)

def cmd_new(title, description, group, opts, settings):
    sa = get_session(settings.dbref)
    if group:
        group = Task.find(( Task.title == group, ), sa=sa)
        assert group, opts.args.group
    task = Task(
            title = title,
            description = description,
            partOf = group
    )
    sa.add(task)
    sa.commit()
    print_Task(task)

def cmd_update(ID, title, description, group, opts, settings):
    sa = get_session(settings.dbref, metadata=metadata)
    task = Task.find(( Task.title == title, ), sa=sa)
    if group:
        group = Task.find(( Task.title == group, ), sa=sa)
        assert group, opts.args.group
    # TODO: title, description
    # TODO: prerequisites...
    # requiredFor...
    # partOf
    # subtasks...
    pass

def cmd_done(ID, settings):
    print 'done', ID

def cmd_reopened(ID, settings):
    print 'reopen', ID

### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    values = opts.args

    # FIXME: share default dbref uri and path, also with other modules
    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'todo.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))


