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
  during record. That is somewhat of a hindrance, but justified by the use case
  of the app: it records an manages time done on 'other tasks'. 

ChangeLog
----------
2011-05-22
  Creation of script.
"""
from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

SqlBase = declarative_base()

class Customers(SqlBase):
    pass
    
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

__options__ = (
)

def main():
    pass

if __name__ == '__main__':
    main()
