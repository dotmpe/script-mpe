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
  during record. That is somewhat of a hindrance, but justified by the use case
  of the app: it records an manages time done on 'other tasks'. 

ChangeLog
----------
2011-05-22
  Creation of script.

"""
import os
import optparse
import sys

from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

import confparse
from libcmd import Cmd

SqlBase = declarative_base()

"""
The standard timeEdition sqlite3 database as of version 1.1.6.
::

    CREATE TABLE customers(id INTEGER PRIMARY KEY, name VARCHAR(255), color VARCHAR(32), icalCalID VARCHAR(255));
    CREATE TABLE projectTasks(id INTEGER PRIMARY KEY, projectID INTEGER, taskID INTEGER);
    CREATE TABLE projects(id INTEGER PRIMARY KEY, name VARCHAR(255), customerID INTEGER, projectTime INTEGER,status INTEGER);
    CREATE TABLE recordStateTable(recStartDate VARCHAR(32), which VARCHAR(10));
    CREATE TABLE records(id INTEGER PRIMARY KEY, fromTime DATETIME, toTime DATETIME, customerID INTEGER, projectID INTEGER, taskID INTEGER, icalEventID VARCHAR(255), comments TEXT, GoogleEditURL VARCHAR(255), OutlookEntryID VARCHAR(255));
    CREATE TABLE tasks(id INTEGER PRIMARY KEY, name VARCHAR(255), rate REAL);
"""

class Customers(SqlBase):
    __tablename__ = 'customers'
    id = Column(Integer(11), primary_key=True)
    name = Column(String(255), unique=True)
    color = Column(String(32))
    icalCalID = Column(String(255))

class ProjectTasks(SqlBase):
    __tablename__ = 'projectTasks'
    id = Column(Integer(11), primary_key=True)
    projectID = Column(ForeignKey('projects.id'))
    taskID = Column(ForeignKey('tasks.id'))

class Projects(SqlBase):
    __tablename__ = 'projects'
    id = Column(Integer(11), primary_key=True)
    name = Column(String(255), index=True)
    customerID = Column(ForeignKey('customers.id'))
    projectTime = Column(Integer())
    status = Column(Boolean())

class RecordStateTable(SqlBase):
    __tablename__ = 'recordStateTable'
    id = Column(Integer(11), primary_key=True)

class Records(SqlBase):
    __tablename__ = 'records'
    id = Column(Integer(11), primary_key=True)

class Tasks(SqlBase):
    __tablename__ = 'tasks'
    id = Column(Integer(11), primary_key=True)

def get_session(dbref):
    engine = create_engine(dbref)
    # Issue CREATE's 
    SqlBase.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    return session


# Main

class WorkLog(Cmd):

    "Class variables"
    DEFAULT_DB = "sqlite:///%s" % os.path.join(
                                    os.path.expanduser('~'), '.%s.sqlite' % NAME)

    OPTIONS = (
    )

    "Instance vars. "

    settings = confparse.Values()
    "Complete Values tree with settings. "
    rc = None
    "Values subtree for current program. "

    def rc_init_default(self):
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
            print "File rewritten. "
        else:
            print "Not writing file. "

if __name__ == '__main__':
    app = WorkLog()
    app.main()
