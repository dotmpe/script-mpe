"""
res.list - Parsers for lists with simple items based on res.txt.

These types parse and represent plain-text files, where each line except blank
lines and comments describe a distinct structured item.
"""
import txt
import txt2
import js



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


class GenericListParser(
): pass
