Rationale
=========
.. note:: introduction

    This document accompanies a Python program.

Task tracking can be a complex use case. 
Its complexity but also its usefulness depends on the amount
and of inter-task relations.

If we were to allow the following cardinality there would have to
be extensive validity checking upon inserting or moving nodes.

::
    
    (dia. 1)      0..1
                   |  partOf
                   |
               +---------+
       0..n ---|  Tasks  |--- 0..n
               +---------+
    pre-           |          required
    requisites     | subTasks      for
                  0..n 


E.g. upon adding a prerequisite/requiredFor connection, many
existing connections need to be checked to ensure there is no paradox.
There is dependency inheritance to be watched for, a prerequisite
can not be also part of any requiredFor, etc.

The check must include all nodes that the inserted node already 
(indirectly) connects too, and nodes that already connect to the node 
target of the new connection.

Alternative structure
---------------------
If we uniquely identify the ranks in time (prerequisite/requiredFor)
or hierarchy (partOf/subTasks) we might help the needed algorithms a bit.
Instead of checking each individual link, we compare the ID of an entire sequence
of links. 

However the many-sides in our cardinality scheme introduces branching meaning we
would need to track multiple ID's to know each branching ranks. Eg. like a
hierarchy has multiple paths, one to reach each leaf. Or iow. each fork adds
another rank.
Only one branch introduces a new branch ID for all of the connected nodes.

Simplification
--------------
Given above, Ted Nelsons Zig-Zag springs to mind as a way to greatly reduce the
needed validation complexity.
Lets say previously two types of connections where introduced:

1. Hierarchy, or containment. This is organisational data to do with
   the place (physical location) or conceptual context of the task.
2. Sequence, ie. order in time. This should be explicit when one tasks depends on
   another, but ofcourse is among many more tasks implicit since only one task can be done at a time. Combined with hierarchy, another form of implicit dependencies are those
   inherited.

UI view
_________
Using ZZ axioms, there is only 0..1 cardinality in each direction. 
Iow. unordered sets of subtasks (with subtasks, etc.) become single-file ranks.
ZZ obscures hierarchies with indirect, and cloned structures to avoid violating
its (2D 'tabular' constrained) axioms. If we insist on projecting our
task-cell/relation-link schema the resulting H- or I-view GUI will lose sight of
important data (what is a node part of? we will have to traverse posward to find
headcells, etc. to reconstruct our conceptual hierarchy). 

That is unless some more specific view is introduced, either to support conceptual
hierarchies or to expose some emerging structure using a novel type of
ZZ view rendering perhaps.

Reconceptualization
____________________
This simplification brings its own emphasis and obscurities we may want to
consider before committing to a scheme of storage/navigation structure.
For example, cycles in given two types of connections as dimensions make no
sense for one-time tasks, or places or conceptual groups or do they?

Ranked structure
_________________
For time-ordered tasks, ZigZag makes perfect sense. 
A ranking can express all steps of a particular task, all subsequent datums of a 
research analysis, etc.

Its quite natural to consider one at a time, one before the other, starting with
one and ending with the last one. In other instances, cycles also make good
sense for recurring protocols.

There seems little further to be wanted than to use a single dimension to
rank prerequisite/requiredFor chains of tasks.

Yet there is something missing. One finished tasks may enable several others,
obviously in case one for example creates or fixes a tool, or a platform to enable
other tasks.
This is where our hierarchy-type links come back in,
and the need to reconsider what was emulated with the earlier model.

Meaning, the result of a task (that enables several other/new tasks)
is what ZigZag treats as a 'cloned' cell. A sort of alias or `transcluded` cell.
Put another way, each tasks can link directly to cell along the prerequisite
dimension without violating the cardinality constraint since it has its own
unique clone. 
(Clones are ranked along their own 'clone' dimension, introducing our first
additional connection or dimension type and a new navigatable structure 
expressing a ranking of clones. The headcell of this rank can be the task
itself (no need to actually differentiate tasks/results for now).

We've also lost the hierarchy dimension. To reintroduce containment of tasks,
we can introduce new dimensions like 'place', 'project', 'group' etc. used
in the same way as the 'prerequisite' dimension.
I guess hierarchy proved to be a tad too generic and obsucring too?

There is some new ambiguity, choices based more on style than purpose.
We could use tailcells instead of headcells. In the dimension name too, there 
is an inherent bipolar "ambiguity", this duality perhaps that before was a part of,
embedded into the structure itself.
The right abstraction could make this entirely a matter of view,
and render opposite forms interchangeably; group/sub, prerequisite/depend,
location/object, identity/clone.

To get the right view, we probably want to differentiate clone dimensions.
One for each dimension we want it for.
There is the choice then wether to always link to a clone for these dimensions.

Prerequisites are meant to express things done once in sequence but not neccesarily
related to time. It is impossible to do two things 
at once, but time is more generic as we could be multitasking by 
alternating/interleaving tasks. Ie. based on where we are we do everything
we can there. Obviously for tasks it would be usefull to be bound a calendar in
some way.

Recap::

1. Dimension prerequisite. A task can only be started or completed if preceding 
   task is done.
2. Dimension time. A task can be planned or required at a certain time, the
   posward links points to datetime cell or cells to express a moment or span 
   on a calendar. Lots of more possibilities here.
2. Dimension clone (multiple instances). 
   Each task has one rank with all its aliases used in prerequisite links,
   and one for each link (iow. alias linked to a) place.
3. Dimension place. Expresses a certain place has certain affordances or objects
   for a task, and vice versa explicates where these are located.
4. Dimension group. Each task can be added to one group, no need for aliases.
   Maybe convenient, maybe not.

Note:
    This note strayed from a model where there was a single type of datum (a task)
    to one where there are cells with various datums, some of which are tasks but 
    we also introduced other datums.

Can it be done
--------------
Wether it is usable or can be evolved to something useful a prototype 
would need to prove.

To leverage storage some legwork may have been done with Diablo (Python) for in memory 
storage and muxdems for serialized formats. New work should probably rely on
Mantra/Diablo protocol or compatible. This allows to further test the given
storage API and the types of routines involved with this type of data.

HaXe is still a tempting choice, not just for client.
Integration with NodeJS is there somehow too, lots of potential.
Platform for Web, CLI single-session or daemonized services.

In cllct there is simple Python ncurses Mantra/Diablo client called 'cursor'.
That worked very well for reading. It would need to be extended to have
multiple cursors. Also, only I and H view work for cell based screens.
Focussing on our 'hierarchy' we may enjoy a HTML5 based solution more.

Not sure how far x-zz-explorer (HaXe/Flash) went.

The author is also not aware of any project with this type of structural 
foundation.
Although various efforts in web technology do seem to afford for certain aspects
of it. I've earlier tried to take ZZ land to RDF, XML, RDBMS and there is prior
art there.

But as a pragmatic solution this clearly is inadequate.
Seeing that we found additional datum types, and having explored task relations
a bit some points have become apparent.

Pragmatic constraints for Tasks entities
----------------------------------------
Amend the proposed model in two ways:

1. We can restrict only concrete tasks to have prerequisites. 
   Ie. never assign them to groups, or if so then always inherit them to leafs
   (as being the concrete steps involved). In implementation terms: we introduce
   another entity type.

2. Additionally we can force dependencies to be 0..1 links, and only at their
   own level ie. either group or task.
   So this can sequence clusters of tasks, or tasks within a group.
   Now validatio of user requests get back to checks for cycles and the rest is 
   constrained and contained in the structure.


Conclusion 'Rationale'
----------------------
The given discourse is perhaps "largely academic" but helpful in understanding
a topic that is an aspect of nearly all software projects.. in some way.

I think this is a good basis for a first jab at a TODO database.
Various script-mpe and other programs have attempted this or need this,
thinking also of values of outlines etc.

Adjusted entity relation diagram given in main program.

Post script
-----------
Normally notes like these go into journal or notes. Keeping it here for now.
