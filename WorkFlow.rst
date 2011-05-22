Working on projects
-------------------

1. During work, timeEdition records time and description per client/project/task.

   .. note:: Implementation

      workLog_ is a CLI tool to augment timeEdition_.

2. When done, freeRadical_ scans descriptions for issue or ticket IDs, asking 
   to create new tickets where needed. Identifying new ToDo's or Issues with 
   the project is an ongoing effort.

   .. note:: Implementation

      freeRadical_ TODO: has a backend to jira and redmine.
   
3. yz is then used to submit the time spent on an issue to the work log of
   the issue tracker. This could be done at the end of each day.

   .. note:: Idea
   
      yz or iSea is just an idea right now.. :)

4. Also, for example each week, a report of all work hours can be generated.

.. _timeEdition: http://www.timeedition.com/en/
.. _workLog: workLog.py
.. _freeRadical: freeRadical.py


ChangeLog
~~~~~~~~~~
2011-05-22
  First version.
