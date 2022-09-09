"""
res.tp - Type juggling to unmarshall types from user-data.
"""
import inspect
import decimal

import uriref

from . import mb
from . import dt


def is_native_or_class(type_):
    "Return true if given symbol is a class or builtin"

    return (
        type_ == getattr( __builtin__, type_.__name__ ) or
        inspect.isclass(type_)
    )

def typebuilder(data, type_, default=None):

    """
    Instantiate new type in one of three ways, with distinct constructor
    argument styles. Two to create or amend list and dictionary types,
    and a third to hande all other string-to-type factories such as int,
    float, bool, etc.

    Both dict and UserDict, vs. list, tuple and UserList expect data to be a
    tuple; either a two-level key, value sequence, or a single-level sequence
    of list items. The default keyword allows to amend and existing instance in
    case of the two complex types, and provide for a default value in each case.
    """

    if type_ == dict:
        if not default:
            default = type_()
        dict.update(*data)
        return default

    elif type_ == list:
        if not default:
            default = type_()
        default.extend(*data)
        return default

    else:
        return type_(*data) or default

def typebuilder_from_re(match, type_, default, *groups):
    """
    Given group-numbers to create data item from match, return data instance
    created with typebuilder.
    """
    data = tuple([ match.group(i) for i in groups ])
    return typebuilder(data, type_, default)


"""
def mydict(
        match.group(key_group), match.group(value_group)
        if not match:
            if allow...
            raise ValueError("Expected %s field: " % name)
            continue
        if not (k and v):
            if self.strict:
                raise ValueError("Expected %s field: " % name)
            continue
"""


# Tie together some regexes and some native and custom types and helpers

typebuilders = {

    'bin':     (mb.num_r('bin',True), bin, 0),
    'oct':     (mb.num_r('oct',True), oct, 0),
    'uint':    (mb.num_r('int'), int, 0),
    'int':     (mb.num_r('int',True), int, 0),
    'dec':     (mb.num_r('dec',True), decimal.Decimal, 0),
    'float':   (mb.num_r('float',True), float, 0),
    'hex':     (mb.num_r('hex',True), hex, 0),
    #'long':    (mb.num_r('long',True), long, 0),
    'sci-dec': (mb.num_r('sci-dec'), decimal.Decimal, 0),
    'complex': (mb.num_r('complex'), complex, 0),

    'bool':    (mb.bool_r, bool, 0),

#    'str':     (mb.str_r, str, 0),
#    'unicode': (mb.unicode_r, unicode, 0),

    'date':    (mb.iso_8601_dt_l_r, dt.parse_isodatetime, 0),
    #'attr':    (mb.meta_c, dict, 2, 3),

    'uriref':  (mb.uriref_simple_netpath_scan_r, uriref.URIRef, 0),
}
