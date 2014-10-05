#!/usr/bin/env python
"""
:created: 2011-12-23

Trying to create simple model to log work. 
Lookup the project for the CWD, and list/add/update tickets and tasks.

Changelog
---------
2011-12-23
    - Moved timeEdition experimental code, starting new generic version.

2012-06-30
    - Rethinking about serial format.
      Items should be branched and sorted dynamically.
      Underlying data is somehting graphlike but with limited associations and
      heuristic implementations.
"""
import os

from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship

import zope

import libcmd
import txs
import res
import taxus
from taxus import Taxus
import taxus.semweb
import taxus.generic



# Data model 

class Project(taxus.semweb.Description):
    """
    """
    __tablename__ = 'wlprojects'
    __mapper_args__ = {'polymorphic_identity': 'worklog-project'}

    project_id = Column('id', Integer, ForeignKey('frags.id'), primary_key=True)


class Ticket(taxus.semweb.Description):
    """
    Represent a task with associated effort.
    """
    __tablename__ = 'wltickets'
    __mapper_args__ = {'polymorphic_identity': 'fragment:worklog-ticket'}

    ticket_id = Column('id', Integer, ForeignKey('frags.id'), primary_key=True)

    project_id = Column(Integer, ForeignKey('wlprojects.id'))
    project = relationship(Project, primaryjoin=project_id==Project.project_id)
    time_estimated = Column(Integer)
    time_spent = Column(Integer)
    #worklog = relationship('Entry', 
    #        primaryjoin='wltickets.id == wlrecords.ticket_id')
    comments = relationship(taxus.generic.Comment, 
            primaryjoin= taxus.Node.node_id == taxus.generic.Comment.annotated_node )
    #status = Column(Enum ...
    active = Column(Boolean)


class Entry(taxus.semweb.Description):
    """
    Represent an expenditure of effort.
    """
    __tablename__ = 'wlrecords'
    __mapper_args__ = {'polymorphic_identity': 'fragment:worklog-record'}

    wl_entry_id = Column('id', Integer, ForeignKey('frags.id'), primary_key=True)

    ticket_id = Column(Integer, ForeignKey('wltickets.id'))
    ticket = relationship(Ticket, primaryjoin=ticket_id == Ticket.ticket_id,
            backref='worklog')

    fromTime = Column(DateTime)
    toTime = Column(DateTime)
    comments = Column(Text)


# Main app

# XXX see radical get that working atain, or mime-reg
class workLog(txs.Txs):

    zope.interface.implements(res.iface.ISimpleCommand)

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DEFAULT_RC = 'cllct.rc'
    DEFAULT_CONFIG_KEY = NAME

    DEFAULT = [ 'tasks' ]

    @classmethod
    def get_optspec(Klass, inheritor):
        """
        Return tuples with optparse command-line argument specification.
        """
        p = inheritor.get_prefixer(Klass)
        return (
            )

    DEPENDS = {
            'tasks': ['txs_session'],
        }

    def tasks(self, opts=None, sa=None):
        print 'All tickets', sa.query(Ticket).all()
        print 'Active tickets', sa.query(Ticket)\
                .filter(Ticket.active == True).all()

    # TODO: perhaps implement export and update from import while I'm to lazy to
    # implement all of the UI.. maybe. requires demux + 

    # Manage project nodes

    project_subcmd_aliases = {
            'rm': 'remove',
            'upd': 'update',
            'ad': 'add',
        }

    def project(self, args, opts):
        subcmd = args[0]
        while subcmd in self.project_subcmd_aliases:
            subcmd = project_subcmd_aliases[subcmd]
        assert subcmd in ('add', 'update', 'remove'), subcmd
        getattr(self, "project_%s" % subcmd)(args[1:], opts)

    def project_add(self, args, opts):
        s = self.session
        projectfile = self.get_config('cllct/project')
        projectdata = confparse.load_path(projectfile)
        pass
# XXX: rethink what to store..
        #projectdata.location.ref
        name = args[0]
        #project_NS = 
        node = Project(name=name,
                date_added=datetime.now(),
                #namespace=project_NS
            )
        print node
        pass

    def project_remove(self, args, opts):
        pass

    def project_update(self, args, opts):
        pass


if __name__ == '__main__':
    workLog.main()
