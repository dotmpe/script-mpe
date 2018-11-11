"""
res.lst - ordered or indexed user-data struct from plain-text files

See `list` frontend and docs.
"""
from zope.interface import implements

import uriref

from script_mpe.confparse import Values

import d
import js
import mb
import txt
import txt2

from pprint import pformat


# Define parser for items (lines, rows) and for lists of items


class ListItemTxtParser_Old(
        txt.AbstractTxtSegmentedRecordParser_Old,
        txt.AbstractTxtRecordParser_Old,
        txt.AbstractRecordIdStrategy_Old,
        txt.AbstractRecordReferenceStrategy_Old
):
    fields = ("sections refs contexts projects cites hrefs attrs "
        "date:creation_date date:deleted_date id:item_id").split(' ')
    implements(txt2.ITxtLineParser)
    def __init__(self, raw, **attrs):
        super(ListItemTxtParser_Old, self).__init__(raw, **attrs)


class ListTxtParser_Old(txt.AbstractIdStrategy_Old):
    implements(txt2.ITxtListParser)
    item_parser = ListItemTxtParser_Old
    def __init__(self, **kwds):
        super(ListTxtParser_Old, self).__init__(**kwds)


### URL Lists

class URLListItemParser(
    txt2.AbstractTxtLineParserRegexFields,
    txt2.AbstractTxtLineParser,
):
    fields = (
        "uriref:url::0",
        "date:last-modified::0",
        "date:last-accessed::0",
        "int:status::0"
    )

    uriref_r = r"<([^>]+)>|(%s)" % mb.uriref_simple_netpath_scan_r

    def __init__(self, *args, **kwds):
        self.field_names.update(dict(
            uriref= (self.uriref_r, uriref.URIRef, 1),
        ))
        super(URLListItemParser, self).__init__(*args, **kwds)

    #def parse_fields(self, text, *args):
    #    return text


class URLListParser(
    txt2.AbstractTxtListParser
):
    """
    Usage::

        iter = URLListParser().load(open('mylist.txt'), 'mylist')

    This `res.txt` configuration uses simple item instances and allows for text
    content in addition to the URL. Also there is no restriction on order
    between diffent types.

    Providing cardinality allows to track multiple values, and to validate
    the number of matches or require one. To further restict the format,
    e.g. reset the fields to match just URL references::

        URLListItemParser.fields = URLListItemParser.fields[0]

    """
    item_parser = URLListItemParser
    item_builder = txt2.SimpleTxtLineItem


# Module shorcuts

list_parse_defaults = dict(
        verbose=0,
        item_builder=None,
        # TODO: 1. give access to lookup indices
        be=dict(),
        return_parser=False,
        record_cites=True
    )

def parse(listfile, g=None, ):

    """
        Parse listfile, either return parser or listitems.

    Create a res.txt parser to load and parse the file. If given an
    item-builder, it is used to initialize items which are returned in a list.
    The parser and contexts will be destroyed, unless return_parser is True.
    """
    if not g: g = Values(list_parse_defaults)

    # Initialize list parser
    kwds = dict(d.pick(g, 'be', 'apply_contexts'))
    items = ListTxtParser_Old(**kwds)
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
    TODO: Write items selected by provider-spec to listfile.
    """
    pass
