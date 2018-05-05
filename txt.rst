Feature: fold/unfold hierarchy (the outline) to/from records (the list)

    TODO.txt lists are suitable for terse task descriptions, but allow for
    very, very long lines to accomodate for all the bits involved by the task.
    To allow for easier plain text editing, a way to break up to and reassemble
    from lines would help.

    The simplest would be to split on meta character(s), a more complex way
    would be to go by substructures, possibly apply cardinality rules. Etc.
    That gives roughly two text op-modes, rearrangement, and insert/remove.
    Rearrangement is probably better left to other extensions, for (un)fold it
    only requires the latter. Iot. simplify parsing as much as possible.

    Enter unfold/fold. Based on the TODO.txt we recognize some extended syntax,
    and identify ranges and nesting level.

    - record-id/sections: retrieve the spans and break up to indented list.
    - lists: break up into lines
    - (date)time annotations


Background:
  TODO: move to syntax docs

  lists have multiple x-refs:

  - cite to record-id or unid
  - provide link from record-id to global id or complex specs via link
    records, ie 'see also', so to keep long strings out of human readable
    records.
