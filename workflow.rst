Working on projects
-------------------

1. During work, timeEdition_ records time and description per client/project/task.

   .. note:: Implementation

      workLog_ is a CLI tool to augment timeEdition.

2. When done, radical_ scans descriptions for issue or ticket IDs, asking 
   to create new tickets where needed. Identifying new ToDo's or Issues with 
   a project is an ongoing effort.

   .. note:: Implementation

      radical_ TODO: has a backend to jira and redmine.
   
3. yz is then used to submit the time spent on an issue to the work log of
   the issue tracker. This could be done at the end of each day.

   .. note:: Idea
   
      yz or iSea is just an idea right now.. :)

4. Reports... for example each week, a report of all work hours should be generated.

.. _timeEdition: http://www.timeedition.com/en/
.. _workLog: workLog.py
.. _radical: radical.py


ChangeLog
~~~~~~~~~~
2011-05-22
  First version.

