#!/usr/bin/env python
"""
Python abstraction of 'timeEdition' database.

- (auto) tag untagged work log entries (append tag to description)
- allow query by client/project/task or issue and

  * print issue-id date time log
  * print date time log

Introduction
-------------
Monitor time spent on work. Every time record is assigned a customer, project
and task ID. The database is initialized by timeEdition, which provides a GUI
to easily toggle the clock on a customer/project/task. It only allows export to
CSV, iCal and XML though so there is no integration with any issue tracking.

- 'task' is a generic description from a set that may be specific to a project
  but by default is a copy of a default list.
- there is no tracking of one single specific task, ie. an issue ID.
- though there is a description attribute for each work log entry.
- there is no on-the-fly switching of client/project/task, the GUI is disabled
  during record. That is somewhat of a shortcoming. Also the record overview is
  implemented as modal dialog. All in all the GUI is convenient but no more
  helpful than that.

ChangeLog
----------
2011-05-22
  Creation of script.
2011-12-18
  Review. Rewrote to use libcmd.

Schema
------
Customer
 * name:String(255)
 * color:String(32)
 * icalEventID:String(255)

Project
 * name:String(255)
 * customer:Customer
 * projectTime:Integer
 * status:Boolean
 * tasks:List<Task>

Record
 * from,toTime:DateTime
 * customer:Customer
 * project:Project
 * task:Task
 * comments:Text

Task
 * name:String(255)
 * rate:Float

"""
from __future__ import print_function
import os
import optparse
import sys

from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index, DateTime, Float
import sqlalchemy.exc
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

from script_mpe import confparse, log
from script_mpe.cmdline import Cmd

SqlBase = declarative_base()

"""
The standard timeEdition sqlite3 database as of version 1.1.6.
::

    CREATE TABLE customers(id INTEGER PRIMARY KEY, name VARCHAR(255), color VARCHAR(32), icalCalID VARCHAR(255));
    CREATE TABLE projectTask(id INTEGER PRIMARY KEY, projectID INTEGER, taskID INTEGER);
    CREATE TABLE projects(id INTEGER PRIMARY KEY, name VARCHAR(255), customerID INTEGER, projectTime INTEGER,status INTEGER);
    CREATE TABLE recordStateTable(recStartDate VARCHAR(32), which VARCHAR(10));
    CREATE TABLE records(id INTEGER PRIMARY KEY, fromTime DATETIME, toTime DATETIME, customerID INTEGER, projectID INTEGER, taskID INTEGER, icalEventID VARCHAR(255), comments TEXT, GoogleEditURL VARCHAR(255), OutlookEntryID VARCHAR(255));
    CREATE TABLE tasks(id INTEGER PRIMARY KEY, name VARCHAR(255), rate REAL);

"""
class Customer(SqlBase):
    __tablename__ = 'customers'
    customer_id = Column('id', Integer, primary_key=True)
    name = Column(String(255), unique=True)
    color = Column(String(32))
    icalCalID = Column(String(255))

class Project(SqlBase):
    __tablename__ = 'projects'
    project_id = Column('id', Integer, primary_key=True)
    name = Column(String(255), index=True)
    customerID = Column(Integer, ForeignKey('customers.id'))
    customer = relationship(Customer,
            primaryjoin=Customer.customer_id==customerID, backref='projects')
    projectTime = Column(Integer())
    status = Column(Boolean())

# XXX: Cannot figure out table recordStateTable. Got one record saying which:
# 'app' and some date. I wonder if this table could be used/expanded to persist
# open sessions.
#class RecordStateTable(SqlBase):
#    __tablename__ = 'recordStateTable'
#    recStartDate = Column(String(32))
#    which = Column(String(255)) # XXX: was 10?

class Record(SqlBase):
    __tablename__ = 'records'
    record_id = Column('id', Integer, primary_key=True)
    fromTime = Column(DateTime)
    toTime = Column(DateTime)
    customerID = Column(Integer, ForeignKey('customers.id'))
    projectID = Column(Integer, ForeignKey('projects.id'))
    taskID = Column(Integer, ForeignKey('tasks.id'))
    icalEventID = Column(String(255))
    comments = Column(Text)
    GoogleEditURL = Column(String(255))
    OutlookEntryID = Column(String(255))

class Task(SqlBase):
    __tablename__ = 'tasks'
    task_id = Column('id', Integer, primary_key=True)
    name = Column(String(255))
    rate = Column(Float)

projectTask = Table('projectTasks', SqlBase.metadata,
    Column('id', Integer, primary_key=True),
    Column('projectID', Integer, ForeignKey('projects.id')),
    Column('taskID', Integer, ForeignKey('tasks.id'))
)
Project.tasks = relationship(Task, secondary=projectTask, backref='projects')


def get_session(dbref, initialize=False):
    engine = create_engine(dbref)
    if initialize:
        # Issue CREATE's
        SqlBase.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    return session


# Main

class WorkLog_timeEdition(Cmd):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DB_PATH = os.path.expanduser('~/Library/Application Support/timeEdition/timeEditionData.edb')
    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

    #TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['query']
    DEFAULT_ACTION = 'stat'

    def get_opts(self):
        return Cmd.get_opts(self) + (
                (('-d', '--dbref'), {
                'default':self.DEFAULT_DB, 'metavar':'URI', 'dest': 'dbref',
                'help': "A URI formatted relational DB access description, as "
                    "supported by sqlalchemy. Ex:"
                    " `sqlite:///radical.sqlite`,"
                    " `mysql://radical-user@localhost/radical`. "
                    "The default value (%default) may be overwritten by configuration "
                    "and/or command line option. "
                }),
                (('-q', '--query'), {'action':'store_true'}),
            )

    def init_config_defaults(self):
        assert False, "TODO: implementing default values for existing settings "

        if self.settings.config_file:
            rc_file = self.settings.config_file
        else:
            rc_file = os.path.join(os.path.expanduser('~'),
                    '.'+self.DEFAULT_RC)

        assert not os.path.exists(rc_file), "File exists: %s" % rc_file
        os.mknod(rc_file)
        self.settings = confparse.load_path(rc_file)

        if config_key:
            setattr(settings, config_key, confparse.Values())
            self.rc = getattr(rc, config_key)
        else:
            self.rc = settings

        "Default some global settings: "
        self.settings.set_source_key('config_file')
        self.settings.config_file = Application.DEFAULT_RC

        "Default program specific settings: "
        self.rc.dbref = Application.DEFAULT_DB

        v = raw_input("Write new config to %s? [Yn]")
        if not v.strip() or v.lower().strip() == 'y':
            self.settings.commit()
            print("File rewritten. ")
        else:
            print("Not writing file. ")

    def init(self, dbref=None):
        session = get_session(dbref, initialize=True)

    def query(self, dbref=None, **opts):
        session = get_session(dbref)
#print list(session.query(Customer).all())
        #print list(session.query(Project).all())
        try:
            for task, project, customer in session.query(Task, Project, Customer).all():#join('projects', 'customer').all():
                print(customer.name, '\t\t',project.name, '\t\t',task.name)
        except sqlalchemy.exc.OperationalError as e:
            log.stderr("Error query DB %s: %s", dbref, e)
            return 1
        print(dbref)

    def stat(self, *args, **opts):
        print('No stats')

if __name__ == '__main__':
    app = WorkLog_timeEdition()
    app.main()
