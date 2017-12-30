"""
orderd or indexed user-data with structure in plain-text files

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
"""
from confparse import Values

import txt
import txt2
import js




# Define parser for items (lines, rows) and for lists of items


class ListItemTxtParser(
        txt.AbstractTxtSegmentedRecordParser,
        txt.AbstractTxtRecordParser,
        txt.AbstractRecordIdStrategy,
        txt.AbstractRecordReferenceStrategy,
):
    fields = ("sections refs contexts projects cites hrefs attrs "
        "date:creation_date date:deleted_date id:item_id").split(' ')
    def __init__(self, raw, **attrs):
        super(ListItemTxtParser, self).__init__(raw, **attrs)


class ListTxtParser(txt.AbstractIdStrategy):
    item_parser = ListItemTxtParser
    def __init__(self, **kwds):
        super(ListTxtParser, self).__init__(**kwds)



# Module shorcuts

list_settings_default = dict(
        verbose=0,
        item_builder_name=None,
    # TODO: give access to lookup indices
        be=dict(),
        return_parser=False,
        record_cites=True
    )

def parse(listfile, g):

    """
        Parse listfile, either return parser or listitems.

    Create a res.txt parser to load and parse the file. If given an
    item-builder, it is used to initialize items which are returned in a list.
    The parser and contexts will be destroyed, unless return_parser is True.
    """
    if not g: g = Values(list_settings_default)

    # Initialize list parser
    kwds = { k: g[k] for k in ('be', 'apply_contexts') }
    items = ListTxtParser(**kwds)
    # parse file
    l = list(items.load_file(listfile))
    # Write to stdout if requested
    if g.verbose:
        for i in l:
            if g.output_format == 'json':
                print(js.dumps(i.todict()))
            elif g.output_format == 'repr':
                print(repr(i))
            else:
                print(str(i))

    if g.return_parser:
        return items, l
    elif g.item_builder:
        return l
    else:
        return items


class ListTxtWriter(txt.AbstractTxtListWriter):
    fields_append = ("contexts projects cites").split(' ')
    def serialize_field_id(self, value):
        return "%s:" % value


def write(listfile, provider_spec):
    """
    Write items selected by provider-spec to listfile.
    """
    pass
