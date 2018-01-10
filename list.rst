:Created: 2012-03-12

Module ``res.list`` provides several list-parser setups using ``res.txt``
abstract types and mixins.

res.list

As such principle goals are

- optional syntax
- dynamic, local extension of the syntax
- variation of the interpretation of the syntax

The generic syntax is the same as todo.txt, here the first objective is to
exploit an additional "markup" to relate hierarchical items::

    ... Tag-Id: ... [Tag-Id] ...

Beyond that some todo.txt code is reproduced, generalized. Basicly it is two
base classes and a lot of mixins. First one to parse lines, second one to
parse files of lines.

Concrete classes can configure abstracts bases and mixins using class
attributes. Simple, but the down-side is this allows to layer fields and create
undesired coupling.

Frontends using res.list
