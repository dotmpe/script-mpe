"""
:Created: 2016-05-22

XML writer module for Jsotk using minidom (xml.dom.minidom).
"""
from __future__ import print_function
import types
import uuid
import re

from xml.dom import minidom
from xml.dom import Node


import confparse


def reader(file, ctx):
    init_ctx(ctx)
    doc = minidom.parse( file )
    root = doc.childNodes[0]
    ctx.xml_raw_data = True
    ctx.xml_dom.attr_pref = ''
    data = xml_to_data( root, ctx )
    return data

def writer(data, file, ctx):
    init_ctx(ctx)
    data_to_xml( data, 0, file, ctx )


def init_ctx(ctx):
    if 'xml_raw_data' not in ctx:
        ctx.xml_raw_data = False
    if 'xml_dom' not in ctx:
        ctx.xml_dom = confparse.Values()
    if 'attr_pref' not in ctx.xml_dom:
        ctx.xml_dom.attr_pref = '@'
    if 'name_key' not in ctx.xml_dom:
        ctx.xml_dom.name_key = '_name'
    if 'text_key' not in ctx.xml_dom:
        ctx.xml_dom.text_key = '#text'
    if 'content_key' not in ctx.xml_dom:
        ctx.xml_dom.content_key = '_'
    if 'indent' not in ctx.xml_dom:
        ctx.xml_dom.indent = '  '
    if 'blank_name' not in ctx.xml_dom:
        ctx.xml_dom.blank_name = '_blank'
    if 'invalid_nchar' not in ctx.xml_dom:
        ctx.xml_dom.invalid_nchar = '_'


re_ws = re.compile('[\s]+')


def xml_to_data( xml, ctx ):
    t_k = ctx.xml_dom.text_key
    n_k = ctx.xml_dom.name_key
    c_k = ctx.xml_dom.content_key
    a_p = ctx.xml_dom.attr_pref
    a_pl = len(a_p)

    obj = dict()

    obj[n_k] = xml.nodeName

    for attr, value in xml.attributes.items():
        obj[a_p+attr] = value

    for child in xml.childNodes:
        if child.nodeType == Node.TEXT_NODE and not re_ws.match( child.data ):
            if t_k not in obj:
                obj[t_k] = ''
            obj[t_k] += child.data

        elif child.nodeType == Node.ELEMENT_NODE:
            if c_k not in obj:
                obj[c_k] = []
            obj[c_k].append( xml_to_data( child, ctx ) )

    if ctx.xml_raw_data:
        return obj
    elif t_k in obj:
        name = obj[n_k]
        r = {t_k: obj[t_k]}
        if name == ctx.xml_dom.blank_name:
            return r
        return {name: r}
    elif n_k in obj:
        name = obj[n_k]
        if c_k in obj:
            r = {name:obj[c_k]}
        else:
            r = {name:None}
        if name == ctx.xml_dom.blank_name:
            return r[name]
        return r
    assert False, obj


def data_to_xml( data, level, out, ctx ):
    """
    Top level should be object type and have one key for proper XML,
    but that is not enforced here. No prolog is added either, or namespace
    handling.

    TODO: no datatypes either. See how that hooks in with NS.
    FIXME: ws. modes preserve-whitespace, indented-elements, indented-text
    """
    n_k = ctx.xml_dom.name_key
    a_p = ctx.xml_dom.attr_pref
    a_pl = len(a_p)

    if type(data) == types.DictType:

        # Output as XML element
        E = {}

        if n_k in data:
            E_name = data[n_k]
            if not re_vn.match(E_name):
                E_name = xml_name(E_name, ctx)
        elif ctx.xml_dom.blank_name:
            E_name = ctx.xml_dom.blank_name
        else:
            E_name = xml_id()

        for key, item in data.items():
            if key.startswith(a_p):
                k = key[a_pl:]
                if not re_vn.match(k):
                    k = xml_name(k, ctx)
                E[key[a_pl:]] = item
                del data[key]

        out.write(xml_indent(level, ctx) + xml_element_start( E_name, **E ) + "\n")
        data_to_xml( item, level+1, out, ctx )
        out.write(xml_indent(level, ctx) + "</%s>\n" % E_name)

    elif type(data) == types.DictType:
        # Output in sequence without envelope
        for item in data:
            data_to_xml( item, level+1, out, ctx )
    else:
        out.write(str(data) + "\n")



def xml_id():
    return str( uuid.uuid1() )

re_vn = re.compile('[A-Za-z_][A-Za-z0-9_]+')
re_vn_fc = re.compile('[A-Za-z_]')
def xml_name(name, ctx):
    if not re_vn_fc.match(name[0]):
        name = ctx.xml_dom.invalid_nchar + name
    if re_vn.match(name):
        name = re.sub('[^A-Za-z0-9_]',
                ctx.xml_dom.invalid_nchar, name)
    return name

def xml_indent( level, ctx ):
    if level:
        return level * ctx.xml_dom.indent
    return ''

def xml_element_start( name, **attr ):
    if attr:
        return "<%s %s>" % ( name,
            " ".join( '%s="%s"' % kv for kv in attr.items() ) )
    else:
        return "<%s>" % name


