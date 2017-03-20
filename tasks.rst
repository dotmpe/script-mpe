
The tasks document is a collection of tickets/calls/todos/... lists.

----

Workflow
  .. figure:: tasks/comp-wf-3.svg
     :target: tasks/comp-wf-3

     With a SLUG-id a comment is matched with to an existing issue, or a new
     issue is initialized from the comment.

     The tracker backend should keep a list of comment-id.
     The comment-id is a unique, short Id for the link between a
     source-embedded-issue and an record in a backend storage.

     If the issue exists anything after the SLUG/issue ID is used
     as a comment on the ticket. Anything before is kept in source only.

     Otherwise, we have a plain tag, like FIXME or NOTE, with or without
     Id. Either way we want to establish a link between the comment and some
     ticket or call, spec, vulnerability report, etc.

     In the end the same rules as with a SLUG-tagged comment apply.

     But to get there:

     - the comment can contain TODO.txt syntax
     - the first backend storage impl. is a TODO.txt file
     - given above user interaction or discretion is required to:

       1. lookup issue, or create one
       2. add slug before, in or after comment

     Initially it may be convenient to pre-enter TODO.txt prio to overrule.
     XXX: But not all data should remain in comment?

  Todo.txt Syntax
    To solve line-number refs breaking, keep a link ID at both sides.
    Use a compact dense-encoded uniqid for the TODO.txt, no hex string UUID's.

    Filenames can be long, and maybe a case could be made to track them:
    for more efficient comment lookup and direct references.
    Not something to keep in the TODO.txt backend, initially. Maybe abbreviated
    paths.

    ID's
      The current radical.py/tasks.py setup scans for unprefixed literal tags
      basicly, and allows an Id argument-sequence to follow the tag.

      Simplicity is key here to, and so the same notation should apply to any
      of the references in the comment. But these maybe external, or of other
      order than the issue that a given comment intents to link too.

    Tag, ID, and Primary vs. Secondary
      There are *two basic classes* of tags:

      1. They describe a *single idea* like a *priority*, a type of activity,
      2. Or are *a name*, for a *list or context*. A grouping, a location, etc.

      That is the literary look at it. For current purposes the first class
      is a short 3-7 letter 'tag'. The second is similary bound, but may
      necessarily grow larger depending on how structurally applied.

      The first class of tags do at themselves not identify the comment.
      But something that needs to be tracked. The second class introduces
      such ID's, but not necessarily a direct match for the current comment.

      In the specific case for radical.py, values for first class are 'XXX',
      'TODO', 'FIXME', which we want to turn into, or link to an existing
      issue. And doing that by introducing a tag from the second class
      consisting of the Project-Slug plus a ticket ID.

      That is the **primary ID**, for a comment to link it as a particular
      instance in a tracker.

      Other **secondary ID** reflect links of that record to other records,
      wether external or internal.

      One specific type of **secondary-ID** is reserved for radical-tasks, that
      is the tag used to find or track the comment, combined with an ID that
      uniquely identifies the comment, as one on the entity of the primary ID.

      The syntax can exploit the fact that TODO.txt sees '<tag>:<id>' meta, or
      not using e.g. '<tag>-<id>'. It does not matter to radical/tasks.

      It also does not matter which class provides the primary ID.
      Or the secondary ID. They do but indicate a way of user interaction.
      Technically only one ID is needed in the comment, and which one depends
      on use.

      This also applies to the first set of tags, those that map to a generic
      idea, or a thing larger than or apart of the project but not the project
      itself. Ie. like the 'TODO', 'XXX' or 'FIXME' tags of source code or other
      documents maybe. Another way to look at it is these are the cass of tags
      that a user uses, and can be regarded as some claim made by the user.
      While the second class is what the project or system uses, has recorded,
      prescribes, etc.

      Both are simple text, ASCII likely, and can be typed as arguments to a
      `grep` call. Or in a web form, or text or search bar input somewhere.
      They have the down-side of getting longer in structural applications.

    Initialize new issue from comment::

      file:123: # TODO: affects gizmo [XYZ-99]
      (D) #:99 src:file:09af
      file:123: # TODO:09af affects gizmo [XYZ-99]

      file:124: # FIXME: [XYZ-101] get the confabulator going
      (C) get the confabulator going #:101 src:90fa
      file:124: # FIXME:90fa [XYZ-101] get the confabulator going

    Or refer and add text to existing issue::

      file:200: # XXX: [XYZ-99] maybe move
      (D) #:99 src:file:123 src:ab12: maybe move
      file:200: # XXX:ab12 [XYZ-99] maybe move

  Processing
    Mass-updates are difficult without at least some configurable behaviours
    in forging or mapping issues, and should be applied in a controlled manner.

    For example, to reproduce the TODO.txt document, only 1 comment with the
    call ID is required, with a compiled list of all referring comment ID's.
    However if any other comment has the SLUG-id then ordering of the comments is
    needed to initiaze the issue from the correct first-one.

    So the mapping implied in above example need not be typical, and essentially
    for the system to work only the comment-id handling is required. Comment
    changes, updates, syncing etc. can be disregarded if irrelevant.


  XXX: Older preliminary component overviews (need cleanup):

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

  # grep -nH
  <file>:<start-line>: <match>

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



