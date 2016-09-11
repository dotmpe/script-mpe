
The tasks document is a lists of tickets/calls/todos.

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



