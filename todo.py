#!/usr/bin/env python
""":created: 2014-08-31

TODO: interface this with Google tasks
"""
__description__ = "todo - time ordered, grouped tasks"
__version__ = '0.0.3' # script-mpe
__db__ = '~/.todo.sqlite'
__usage__ = """
Usage:
  todo.py [options] info
  todo.py [options] list
  todo.py [options] find <title>
  todo.py [options] rm ID...
  todo.py [options] insert <title> <before-ID>
  todo.py [options] (new|update <ID>) <title> [<description> <group>]
  todo.py [options] (import <input>|export)
  todo.py [options] (start|stop|finish|reopen) <ID>...
  todo.py [options] (ungroup) <ID>...
  todo.py [options] ID prerequisite PREREQUISITES...
  todo.py [options] ID depends DEPENDENCIES...
  todo.py help
  todo.py -h|--help
  todo.py --version

Options:
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    -i FILE --input=FILE
    -o FILE --output=FILE

Other flags:
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

Model::

    (dia. 1a)
          Task
            - id Int
            - title String(255)
            - description Text
            - refs List<URL>

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

- XXX: Refs allows for extensions; and link to embedded tagged comments::

    file:///<filepath>;line=<line>
    file:///<filepath>;line=<line>#TODO:<n>
    file:///<dirpath>;project=<label>/<filename>;...#TODO:<n>

- XXX: The above allows to refer to tags: TODO, etc. Nothing implied here.
  Would like to create function for local (project specific) todo management.

""" % ( __db__, __version__ )
from datetime import datetime
import os
import re
import hashlib
from pprint import pformat

import log
import util
from taxus import Node
from taxus.util import ORMMixin, ScriptMixin, get_session
from res import js

from sqlalchemy import Column, ForeignKey, Integer, String, Boolean, Text, create_engine
from sqlalchemy.orm import Session, relationship, backref,\
                                joinedload_all
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm.collections import attribute_mapped_collection




SqlBase = declarative_base()


class Task(ORMMixin, SqlBase):

    """
    """

    __tablename__ = 'tasks'

    task_id = Column('id', Integer, primary_key=True)
    #task_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)
    key_names = ['task_id']

    title = Column(String(255), unique=True)
    description = Column(Text, nullable=True)

    partOf_id = Column(Integer, ForeignKey(task_id))

    subtasks = relationship('Task',
            cascade="all, delete-orphan",
            backref=backref("partOf", remote_side=task_id),
            foreign_keys=[partOf_id],
            #collection_class=attribute_mapped_collection('title')
        )

    #prerequisite_id = Column(Integer, ForeignKey(task_id))
    requiredFor_id = Column(Integer, ForeignKey(task_id))
    "Indicate another tasks depends on completion of this task. "
    "This is the prerequisite side. "

    requiredFor = relationship('Task',
            backref=backref('prerequisite', remote_side=task_id),
            foreign_keys=[requiredFor_id])

    def copy(self, plain=False):
        if plain:
            r = {}
            for k, v in self.__dict__.items():
                if k.startswith('_'):
                    continue
                if k+'_id' in self.__dict__:
                    continue
                r[k] = v
            return r
        else:
            return Task(
                    title=self.title,
                    description=self.description,
                    partOf_id=self.partOf_id)

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
"{blue}%s{bblack}. {bwhite}%s {bblack}[{magenta}%s {green}%s{bblack}]{default}" % (
                task.task_id,
                task.title,
                task.requiredFor_id and task.requiredFor_id or '',
                task.partOf_id and task.partOf_id or ''
            )
        )


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
    print pformat(settings.todict())

def cmd_list(settings):
    sa = get_session(settings.dbref)
    roots = sa.query(Task).filter(Task.partOf_id == None).all()
    indented_tasks('', sa, settings, roots)

def cmd_find(title, settings):
    sa = get_session(settings.dbref)
    task = Task.find(( Task.title == title, ), sa=sa)
    print_Task(task)

def cmd_new(title, description, group, opts, settings):
    """
        todo [options] new <title> <description> <group>
    """
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

def cmd_insert(title, before_ID):
    """
        todo [options] insert <title-or-ID>
    """
    sa = get_session(settings.dbref, metadata=SqlBase.metadata)
    before = Task.fetch(((Task.task_id == before_ID[0]),), sa=sa)
    task = Task(title=title, prerequisite_id=before.task_id)
    sa.add(task)
    sa.commit()

def cmd_update(ID, title, description, group, opts, settings):
    sa = get_session(settings.dbref, metadata=SqlBase.metadata)
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

def cmd_rm(ID, settings):
    """
        todo rm ID...

    Delete tasks.
    """
    sa = get_session(settings.dbref, metadata=SqlBase.metadata)
    for id_ in ID:
        task = Task.fetch(((Task.task_id == id_),), sa=sa)
        sa.delete(task)
        sa.commit()
        print_Task(task)

def cmd_export(output, settings):
    """
        todo export -o FILE
    """
    output = output or settings.output
    assert settings.output, "Missing output file."
    sa = get_session(settings.dbref, metadata=SqlBase.metadata)
    tasks = sa.query(Task).all()
    data = {
        'version': __version__,
        'tasks': [ t.copy(True) for t in tasks ]
    }
    js.dump(data, open(settings.output, 'w+'))

def cmd_import(input, settings):
    """
        todo import -i FILE
    """
    input = input or settings.input
    assert input, "Missing input file."
    sa = get_session(settings.dbref, metadata=SqlBase.metadata)
    json = js.load(open(input, 'r'))
    assert json['version'] == __version__, json['version']
    for t in json['tasks']:
        task = Task(**t)
        sa.add(task)
    sa.commit()

def cmd_start(ID, settings):
    """
        todo start ID...
    """

def cmd_stop(ID, settings):
    """
        todo stop ID...
    """

def cmd_finish(ID, settings):
    """
        todo finish ID...
    """

def cmd_reopen(ID, settings):
    """
        todo reopen ID...
    """

def cmd_prerequisite(ID, PREREQUISITES, settings):
    """
        todo ID depends PREREQUISITES...

    (Re)Set ID to depend on first prerequisite ID. If more prerequisites are
    given, apply the same to every following ID in sequence.

    This sets an unqualified dependency.
    TODO: check level
    """
    sa = get_session(settings.dbref, metadata=SqlBase.metadata)
    node = Task.byKey(dict(task_id=ID), sa=sa)
    for prereq_ID in PREREQUISITES:
        node.requiredFor_id = prereq_ID
        sa.add(node)
        node = Task.byKey(dict(task_id=prereq_ID), sa=sa)
    else:
        node.requiredFor_id = None
        sa.add(node)
    sa.commit()

def cmd_depends(ID, DEPENDENCIES, settings):
    """
        todo ID requires DEPENDENCIES...

    """
    sa = get_session(settings.dbref, metadata=SqlBase.metadata)
    node = Task.byKey(dict(task_id=ID), sa=sa)
    for dep_ID in DEPENDENCIES:
        dep = Task.byKey(dict(task_id=dep_ID), sa=sa)
        dep.requiredFor_id = ID
        sa.add(dep)
        ID = dep_ID
    else:
        dep = Task.byKey(dict(requiredFor_id=ID), sa=sa)
        dep.requiredFor_id = None
        sa.add(dep)
    sa.commit()

def cmd_ungroup(ID, settings):
    """
        todo ungroup ID
    """
    sa = get_session(settings.dbref, metadata=SqlBase.metadata)
    for id_ in ID:
        node = Task.byKey(dict(task_id=id_), sa=sa)
        node.partOf_id = None
        sa.add(node)
    sa.commit()


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

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'todo.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))


