.. include:: .default.rst

Tasks
========
:created:

TODO.txt lists boil down to a format for line-based indexed items.

A tasks document is a collection of tickets/calls/todos/...
Of task lists with names, and per item contexts, project homes...

Building prototype commands within ``htd tasks`` command and lib namespace.

Format
------
It is useful to define a common format for plain-text list items. Not just for
tasks, or todo's.

This is the more or less official basic format for TODO.txt lines, as provided
by e.g. `todotxt/todotxt <https://github.com/todotxt/todo.txt>`_.

todo.txt::

  (prio) <created> description +project @context due:<date> [WAIT]
  x (prio) <closed> <created> description +project @context due:<date> [WAIT]

The above organizes tasks on four axis: priority, project, context, and time.
Projects can be seen as another context. But in reality the project is where you
may want to keep the original or canonical TODO.txt. Its a matter of where you
want to keep the lists.

Other metadata can be added as key:values, or maybe TAG's.
The tag WAIT is given for tickets on hold.

For `todo-txt-machine` it is not problem to deal with common path (element)
separators ``:/.``. So various naming schemes can be defined to further
structured projects and contexts. Also routines can use simple prefix matching.

File location can give additional data.

Format extensions
-----------------
Some things about TODO.txt are a bit too specific for my taste.

- Use ``<closed>`` as due-date, as long as the ticket is not closed.

  A plain text task format and no standard syntax way to give the date the tasks
  actually needs to have been done. That bothers me. Also aside from needing
  translation, the ``due:`` meta field seems like a hack to me. What if I called
  it `Due`, or `at` or `when`. Its not right to have a format, with position
  for one or more dates and not plan for one of the essential attributes of
  your domain model.

- What sort of field is ``[WAIT]`` suposed to be? some form of tag? Again, to
  seems an inappropiate addition of new syntax to the format. Altough it is
  nicely readable, so plus there.

  What it does look like is an editor remark or an citation xref. That makes
  sense to include maybe a note about in the standard.

- Next be more lenient in the values for some fields. E.g.
- why not allow priorities from AAA-ZZZ, or A.1, etc. This makes sense if some
  processor is going to work on syncing or processing the task lines. Or even
  If you want to insert an item in between two priorities.

- Then maybe use a character prefix to signal a hold, wait or impeded state.
  Allow any single char in front of an item, to signal some user or system
  defined state.

  Instead of abusing meta fields or inventing other tags, prescribe
  just a hand full and let people invent their own states whichever way they
  want.

  Only requires the description to never start with a single char plus space::

    x this item is closed
    w this one on hold
    b this one is blocked, by another task
    ! this one is an impedement because it's stalled / blocking other tasks
    ? ... make up your own do/cant/want states as needed

  Lets generalize the ``x `` prefix string into someting more generic, and
  customizable. What it lacks, is readability, and an alternative field could
  make up for that. In fact I think ``[TAG]`` is the candidate for that. That
  then leaves just the types of tag/state to predefine, and/or which can be
  used alternatively.

- Some morefields. One for locations, machine addresses, URL's, URN's, file
  paths, url paths: ``<scheme:path>`` (use angled brackets). User interfaces
  may hide the ID's, symbolize them, etc.

  And one field for a basic user link: ``~user``. Simple.

  Again, be as lenient as possible in the allowed characters, to let systems
  come up with their own spaces of values as fitting for the context.

- Last, but not least, I've been rooting for some structure.. One method that
  came is the semicolon. The text before marks an ID or title for the text
  after, and by incrementing the depth a nested structure of sections emerges.

  It needs just the semicolon, and either special status for the period '.'
  character, or use a no-whitespace title Id rule. For example::

    Main-Title: Subtitle-1:: Blah Subtitle-2:: Foo @Ctx +Project [TAG]
    Main Title: Subtitle 1:: Blah. Subtitle 2:: Foo. @Ctx +Project [TAG]

  One main section, two subsections. And all tags appended to the item.
  Once structure is introduced into the system though, it would be interesting
  to be able to place tags in the sections selectively.


I'd digg some standardized processing. But I see the format is too minimal and
the applications to specialized to realy be concerned about generalized
backend/sync/processing rules. So lets get on with planning the system.

Plan
-----
Initial backend support. Local, but also gtasks, redmine.
Sync dev with main Htd_ plans.

First backend specifically for tasks is 'Track' `trc` which is intended to do the TAG-Id like things that radical.py was also started for years ago. But this time for a possible htd proc namespace.

Also coined for backend is 'Source' `src` to access comments combined with possibly a Tag-Id, or another such format.

TODO: list



::

  <pd-root>
    .projects.yml
      ..

    <prefix>/<project>
      todo.txt::

        (B) do this +another-project @laptop @box

Inferred:

- task is associated with +project implicitly.


Dev
-----
htd tasks.hub be.trc
  ..


Tasks
------

Issues
------


Spec
-----
.. If possible, link to test results

----

.. See .default for document structures

----

Syntax
  - todo.txt vim file in ~/.vim/bundle/todo.txt-vim/syntax/todo.vim
  - tests in ~/htdocs/to/do.list
  - verbose syntax description in ~/.vim/bundle/todo.txt-vim/README.rst

  * TODO: get VIM tooling for new Id insertion
  * TODO: get Sh, VIM tooling for new Object Id generation
  * TODO: get Sh, VIM tooling for Task migration

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

      file:123: # TODO: affects gizmo [XYZ-99]                     # tasks.ignore
      (D) #:99 src:file:09af                                       # tasks.ignore
      file:123: # TODO:09af affects gizmo [XYZ-99]                 # tasks.ignore

      file:124: # FIXME: [XYZ-101] get the confabulator going      # tasks.ignore
      (C) get the confabulator going #:101 src:90fa                # tasks.ignore
      file:124: # FIXME:90fa [XYZ-101] get the confabulator going  # tasks.ignore

    Or refer and add text to existing issue::

      file:200: # XXX: [XYZ-99] maybe move                         # tasks.ignore
      (D) #:99 src:file:123 src:ab12: maybe move                   # tasks.ignore
      file:200: # XXX:ab12 [XYZ-99] maybe move                     # tasks.ignore

    Project ID, or SLUG
      Essentially a special kind or variation of context tag. It equals a
      project ID, myabe the same as SLUG or not. For managing projects see
      `package.y*ml`__

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
