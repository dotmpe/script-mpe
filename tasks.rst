
The tasks document is a collection of tickets/calls/todos/... lists.

----

Workflow
  .. XXX: cleanup .. figure:: tasks/wf.png
     :target: tasks/wf

  .. figure:: tasks/comp-wf-1.svg
     :target: tasks/comp-wf-1

     Radical workflow. Only extracting references is implemented.

  .. figure:: tasks/comp-wf-2.svg
     :target: tasks/comp-wf-2

     Index numbering workflow.

  .. figure:: tasks/comp-wf.svg
     :target: tasks/comp-wf

     CLI record update/sync pipeline?

----

todo.txt::

  (prio) <created> description +project @context due:<date> [WAIT]

The above organizes tasks on four axis: priority, project, context, and time.
Other metadata can be added as key:values, or maybe TAG's.
The tag WAIT is given for tickets on hold.

For `todo-txt-machine` it is not problem to deal with common path (element)
separators ``:/.``. So various naming schemes can be defined to further
structured projects and contexts. Also routines can use simple prefix matching.

File location can give additional data.

::

  <pd-root>
    .projects.yml
      ..

    <prefix>/<project>
      todo.txt::

        (B) do this +another-project @laptop @box


Inferred:

- task is associated with +project implicitly.



Getting tasks from source
-------------------------
`radical` handles parsing of tagged comments. But rather than list all tasks
verbatim in source, the list of tagged comments is more of annotations.
With refererence(s) to actual tickets.

Either the tasks list format needs to express this relation between tickets
and source annotations. Or the annotations need some kind of plumbing
to the tickets in the tasks document, and/or back.

The apt way to do this, is by using the ID that external issue trackers would
also be using.
The local taskdoc functions as the canonical list of current issues.

To map a todo to a source file line, it needs something additional.

::

  (A) PRJ-09af

::

  <prefix>/<project>:<file>:<char-range> PRJ-09af-1
  <prefix>/<project>:<file>:<char-range> PRJ-09af-2

To keep these together, there is one tag specific to the project, set or given
somewhere. This also enables creating new tasks for new found tagged
comments. And meanwhile allows other tags with the same format present.

----




Sh (line-based) formats::

  <file>:<start-line>: <match> # grep

  TODO: sh, id formatting

  :<file>:<line-range>:lines=<>;flavour=<>;comment=<> # full-id
  <prefix>:<file>:<line-range>:lines=<>;flavour=<>;comment=<> # full-id

  :<file>:<line-range>::::<>: # full-sh
  <prefix>:<file>:<line-range>:<line-span>:<descr-range>:::<comment-range>:::
  <prefix>:<file>:<line-range>:<line-span>::<descr-offset-span>:::<cmnt-offset-range>::
  <prefix>:<file>:<line-range>:<line-span>:::<descr-line-offset-span>:::<cmnt-line-offset-range>:

  <1-prefix>:<2-file>:<3-line-range>:<4-line-span>:<5-descr-range>:::<8-comment-range>:::
  <1-prefix>:<2-file>:<3-line-range>:<4-line-span>::<6-descr-span>:::<9-cmnt-span>::
  <1-prefix>:<2-file>:<3-line-range>:<4-line-span>:::<7-descr-line-span>:::<10-cmnt-line-span>:

  <prefix>/<project>:<file>:<line-range>::::
  <prefix>/<project>:<file>::<comment-char-range>:::
  <prefix>/<project>:<file>:::<line-range>::
  <prefix>/<project>:<file>::::<description-char-range>: <tag>



