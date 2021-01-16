``feature.txt``
================

`TODO.txt` lists are suitable for terse task descriptions, but allow for
very, very long lines which are not very nice to edit. To accommodate for
all the bits involved by a task, the texts and tag parts can easily (will)
grow beyond "terse". Splitting into different files with specific scopes
can only alleviate a little to none.

To allow for easier plain text editing and accommodate for growth, a way to
break up items and pull-out reusable parts common to sets of items to and
reassemble from lines would help.

The TODO.txt format already defines some meta parts, we need to add
rules for breaking up tasks into parts and vice versa, and one or more
formats to represent those parts in broken down form.
The simplest way would be to extract TODO.txt tags and other fields, lookup
the usage histogram for each part, and then output an indented text file with
extracted parts as nodes. Our target format could also allow (soft)
linebreaks, while ofcourse TODO.txt files have no newlines in task descriptions.

This however creates a strictly exclusive nesting of tasks under items.
With lots of parts, this may create a long file if nothing smart is done
about combining nodes ie. by adjacency.


would be to split on meta character(s), a more complex way
would be to go by substructures, possibly apply cardinality rules. Etc.

That gives roughly two text op-modes, rearrangement, and insert/remove.

Rearrangement is probably better left to other extensions, for (un)fold it
only requires the latter. Iot. simplify parsing as much as possible.

Enter unfold/fold. Based on the TODO.txt we recognize some extended syntax,
and identify ranges and nesting level.

- record-id/sections: retrieve the spans and break up to indented list.
- lists: break up into lines
- (date)time annotations


..
