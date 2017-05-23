"""
Item parser for script-mpe.res

Lists are plain-text files where each line describes a distinct item,
like an entry or record. They are used for accessible persisted storage of items
that travel between other storage backends, or to allow for low-UI or automated
shell interaction with the data.

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
import txt
import js


class ListItemTxtParser(
        txt.AbstractTxtSegmentedRecordParser,
        txt.AbstractTxtRecordParser,
        txt.AbstractRecordIdStrategy,
        txt.AbstractRecordReferenceStrategy
):
    fields = ("sections refs contexts projects cites hrefs "
        "date:creation_date date:deleted_date id:item_id").split(' ')
    def __init__(self, raw, **attrs):
        super(ListItemTxtParser, self).__init__(raw, **attrs)

class ListTxtParser(txt.AbstractIdStrategy):
    item_parser = ListItemTxtParser
    def __init__(self, **kwds):
        super(ListTxtParser, self).__init__(**kwds)

def parse(listfile, list_settings):
    """
    Parse items from listfile.
    """
    kwds = dict( be=dict(), record_cites=True )
    if list_settings.apply_contexts:
        kwds['apply_contexts'] = list_settings.apply_contexts
    if hasattr(list_settings, 'be'):
        kwds['be'] = list_settings.be
    items = ListTxtParser(**kwds)
    l = list(items.load_file(listfile))
    if list_settings.verbose:
        for i in l:
            if list_settings.output_format == 'json':
                print(js.dumps(i.todict()))
            elif list_settings.output_format == 'repr':
                print(repr(i))
            else:
                print(str(i))
    return items, l


class ListTxtWriter(txt.AbstractTxtListWriter):
    fields_append = ("contexts projects cites ").split(' ')
    def serialize_field_id(self, value):
        return "%s:" % value


def write(listfile, provider_spec):
    """
    Write items selected by provider-spec to listfile.
    """
    pass


