"""
"""
# TODO: replace txt.*Parser* with txt2

import re
from collections import OrderedDict

from script_mpe import log, confparse

from . import mb
from . import task



class AbstractTxtLineParser_Old(object):
    fields = ()
    def __init__(self, raw, parser=None, **attrs):
        super(AbstractTxtLineParser_Old, self).__init__()
        self._raw = t = raw.strip()
        self.attrs = attrs
        # Access to parent parser, if needed to bring session onto instance
        self.parser = parser
        # Parse fields
        for f in self.fields:
            t = self.run_field_parse(t, *f.split(':'))
        self.text = t
    def run_field_parse(self, text, method, attr=None):
        if not attr:
            attr = method
        text = getattr(self, 'parse_'+method)( text, attr )
        if hasattr(self.parser, 'handle_'+method):
            v = getattr(self, attr, None)
            if v:
                getattr(self.parser, 'handle_'+method)(self, v, attr)
        #if not getattr(self, attr, None):
        #    setattr(self, attr, None)
        return text
    def list_field_types(self):
        return [
            f.split(':')[0] for f in self.fields
        ]
    def list_field_names(self):
        return [
            f.split(':')[-1] for f in self.fields
        ]
    def todict(self):
        d = dict(
                attrs=self.attrs,
                text=self.text,
                _raw=self._raw
            )
        for f in self.fields:
            if hasattr(self, f): v = getattr(self, f)
            else: v = None
            d[f] = v
        return d
    def __str__(self):
        return self.text
    def __repr__(self):
        return "%s(%r)" % ( self.__class__.__name__, self.text )


class AbstractTxtSegmentedRecordParser_Old(AbstractTxtLineParser_Old):
    section_key_re = re.compile(r"(^|\W|\ )([%s]+):(\ |$)" % (
        task.meta_tag_c ))
    def __init__(self, raw, **attrs):
        self.sections = {}
        super(AbstractTxtSegmentedRecordParser_Old, self).__init__(raw, **attrs)
    def parse_sections(self, t, tag=None):
        for sk_m in self.section_key_re.finditer(t):
            k = sk_m.group(2)
            if k not in self.sections:
                pass # log.warn("Duplicate section %s at line %i" % ( k,
                # self.attrs['doc_line'] ))
                continue
            self.sections[k] = sk_m.span()
        return t


class AbstractTxtRecordParser_Old(AbstractTxtLineParser_Old):
    """
    A list-item parser that interacts with local and remote Id strategies
    on the container::

        @context
        +project
        [cite]
    """
    cite_re = re.compile(r"\ \[([%s]+)\](\ |$)" % ( task.meta_tag_c ))
    href_re = re.compile(r"\ <([^\ >]+)>(\ |$)")
    start_c = r'(^|\W)'
    end_c = r'(?=\ |$|[%s])' % mb.excluded_c
    project_re = re.compile(r"%s\+([%s]+)%s" % (start_c, task.prefixed_tag_c, end_c))
    context_re = re.compile(r"%s@([%s]+)%s" % (start_c, task.prefixed_tag_c, end_c))
    meta_re = re.compile(r"%s([%s]+)\:([%s]+)%s" % (start_c,
        task.prefixed_tag_c, task.prefixed_tag_c, end_c))
    dt_r = re.compile("^\s*([0-9]{4}-[0-9]{2}-[0-9]{2})\ |$")
    def __init__(self, raw, **attrs):
        self.cites = []
        self.hrefs = []
        self.state = None
        self.dates = None
        self.contexts = []
        self.projects = []
        super(AbstractTxtRecordParser_Old, self).__init__(raw, **attrs)
    def parse_attrs(self, t, tag):
        attr, cl = {}, []
        for meta_m in self.meta_re.finditer(t):
            k, v = meta_m.group(2), meta_m.group(3)
            if not meta_m or not (k and v): continue
            attr[k] = v
            cl.append(meta_m.span())
        cl.reverse()
        attr = self.parser.handle_attr(self, attr)
        self.attrs.update(attr)
        for sp in cl:
            t = t[:sp[0]]+t[sp[1]:]
        return t
    def parse_hrefs(self, t, tag):
        cl = []
        for href_m in self.href_re.finditer(t):
            href = self.parser.handle_href(self, href_m.group(1))
            self.hrefs.append(href)
            cl.append(href_m.span())
        cl.reverse()
        for sp in cl:
            t = t[:sp[0]]+t[sp[1]:]
        return t
    def parse_cites(self, t, tag):
        cl = []
        for cite_m in self.cite_re.finditer(t):
            cite = self.parser.handle_cite(self, cite_m.group(1))
            self.cites.append(cite)
            cl.append(cite_m.span())
        cl.sort()
        cl.reverse()
        for sp in cl:
            t = t[:sp[0]]+t[sp[1]:]
        return t
    def parse_projects(self, t, tag):
        cl = []
        for proj_m in self.project_re.finditer(t):
            if not proj_m or not proj_m.group(2): continue
            project = self.parser.handle_project(self, proj_m.group(2))
            self.projects.append(project)
            cl.append(proj_m.span())
        cl.sort()
        cl.reverse()
        for sp in cl:
            t = t[:sp[0]]+t[sp[1]:]
        return t
    def parse_contexts(self, t, tag):
        cl = []
        for m in self.context_re.finditer(t):
            if not m or not m.group(2): continue
            context = self.parser.handle_context(self, m.group(2))
            self.contexts.append(context)
            cl.append(m.span())
        cl.sort()
        cl.reverse()
        for sp in cl:
            t = t[:sp[0]]+t[sp[1]:]
        return t
    def parse_state(self, t, tag):
        #self.parser.handle_state
        if t.startswith("d "):
            self.state = 'completed'
            t = t[2:]
        elif self.creation_date:
            self.state = 'created'
        return t
    def parse_date(self, t, tag='date'):
        m = self.dt_r.match(t)
        if m:
            setattr(self, tag, m.group(1))
            return t[sum(m.span()):]
        else:
            setattr(self, tag, None)
        return t
    def parse_creation_date(self, t, tag):
        m = self.dt_r.match(t)
        if m:
            self.creation_date = m.group(1)
            return t[sum(m.span()):]
        return t
    def parse_completion_date(self, t, tag):
        m = self.dt_r.match(t)
        if m:
            self.completion_date = m.group(1)
            return t[sum(m.span()):]
        return t


class AbstractRecordIdStrategy_Old(AbstractTxtLineParser_Old):
    """
    Mixing for records to retrieve Id, working together with AbstractIdStrategy_Old
    iface on container.
    """
    key_re = re.compile(r"(^|\W|\ )([%s]+):(\ |$)" % (
        task.meta_tag_c ))
    def __init__(self, raw, **attrs):
        super(AbstractRecordIdStrategy_Old, self).__init__(raw, **attrs)
    def parse_id(self, t, tag):
        if self.sections:
            # First section is id for item
            id_dsp = min([dsp for dsp, wid in self.sections.values()])
            for key, (dsp, wid) in self.sections.items():
                if id_dsp == dsp:
                    setattr(self, tag, key)
        else:
            m = self.key_re.search(t)
            if m:
                setattr(self, tag, m.group(2))
                return t[sum(m.span()):]
            else:
                print('Missing ID %s' % t)
        return t


class AbstractRecordReferenceStrategy_Old(AbstractTxtLineParser_Old):
    def __init__(self, raw, **attrs):
        self.refs = {}
        super(AbstractRecordReferenceStrategy_Old, self).__init__(raw, **attrs)
    def parse_refs(self, txt, tag):
        return txt



### List parsers


class AbstractTxtListParser_Old(object):

    """
    The base class for text.list file parsers has methods to parse and process
    one list of items and deal with parsed instances.

    Parsing is done in
    sequence by one line-parser instance.

    Two attributes provide per-line or
    per-item access to parser results: line_contexts and items.

    In addition self.proc is called after parsing and indexing each item,
    before the itm is yielded to the caller of AbstractTxtListParser.load.
    """

    item_parser = AbstractTxtRecordParser_Old
    "The line-parser class"

    # Initialize/reset parser

    def __init__(self, be={}, apply_contexts=[]):
        assert isinstance(apply_contexts, list), apply_contexts
        super(AbstractTxtListParser_Old, self).__init__()
        if not isinstance(be, confparse.Values):
            be = confparse.Values(be)
        self.be = be
        self.apply_contexts = apply_contexts

    def proc_backend(self, ctx, it):
        sa_ctx = self.be.sa_contexts[ctx]
        if not hasattr(sa_ctx, 'proc_context'):
            log.warn("No proc-backend for SQLAlchemy %r" % ctx)
            return False
        return sa_ctx.proc_context( it )
    def proc_backends(self, ctx, it ):
        if self.be.sa_contexts:
            if ctx in self.be.sa_contexts:
                it = self.proc_backend( ctx, it )
        return it
    def proc(self, items):
        for it in items:
            for ctx in it.contexts:
                self.proc_backends( ctx, it )
    def load(self):
        for store_name, store in self.be.items():
            print(store_name)
    def load_file(self, fn):
        "Parse items from a file, yielding %s instances"
        line = 0
        if hasattr(fn, 'read'):
            self.doc_name = fn.name
            lines = fn.readlines()
        else:
            self.doc_name = fn
            lines = open( fn ).readlines()
        assert isinstance(self.doc_name, str), self.doc_name
        for itraw_str in lines:
            itraw = itraw_str.decode('utf-8')
            line += 1
            itraw_ = itraw.strip()
            if not itraw_ or itraw_[0] == '#': continue
            it = self.parse(itraw, doc_name=self.doc_name, doc_line=line)
            #self.load(it)
            for ctx in self.apply_contexts:
                if ctx not in it.contexts:
                    it.contexts.append(ctx)
            yield it
    def parse(self, txtitem, **attrs):
        return self.item_parser( txtitem, parser=self, **attrs )


#

class AbstractIdStrategy_Old(AbstractTxtListParser_Old):

    """
    By providing a 'records' attribute on the container, allow indexed access to
    items by Id. And for record parsers to check for existing reference.
    """

    item_parser= AbstractRecordIdStrategy_Old

    def __init__(self, record_cites=False, **kwds):
        self.records = OrderedDict()
        self.references = {}
        self.record_cites = record_cites
        super(AbstractIdStrategy_Old, self).__init__(**kwds)
    def items(self):
        return self.records.values()
    def init_id(self, record):
        self.records[record.record_id] = record
    # TODO: no on-init ctx/prj/ref/cite handling yet. see AbstractTxtListParser.proc
    def handle_id(self, item, sid, attr=None):
        assert sid, sid
        assert sid not in self.records, "Dupe ID: %r" % sid
        self.records[sid] = item
        return sid
    def handle_context(self, item, ctx, attr=None):
        return ctx
    def handle_project(self, item, project, attr=None):
        return project
    def handle_attr(self, item, a, attr=None):
        return a
    def handle_href(self, item, href, attr=None):
        return href
    def handle_cite(self, item, cite, attr=None):
        if self.record_cites:
            self.references[cite] = None
        else:
            assert ( cite in self.records or cite in self.references ), "Invalid citation: %s" % cite
        return cite
    def handle_ref(self, item, refid):
        assert ( refid in self.records or refid in self.references ), "Invalid reference: %s" % refid
        return refid
    def find_url(self, href, all=False):
        r = []
        for I, i in self.records.items():
            if i.hrefs and href in i.hrefs:
                if all:
                    r.append(i)
                else:
                    return i
        return r


class AbstractTxtListWriter(object):

    """
    Helper for txt list writer.
    TODO see res/todo.py writer and describe differences
    """

    fields_append = ()
    def __init__(self, parser, ignore_hidden_fields=True,
            ignore_hidden_attr=True, ignore_attr=['doc_name', 'doc_line']):
        self.parser = parser
        self.ignore_hidden_attr = ignore_hidden_attr
        self.ignore_hidden_fields = ignore_hidden_fields
        self.ignore_attr = ignore_attr

    def serialize_field_attrs(self, value):
        r = ''
        for k, v in value.items():
            if k in self.ignore_attr: continue
            if self.ignore_hidden_attr and k.startswith('_'): continue
            r += ' %s:%s' % ( k, v )
        return r.strip()

    def serialize_field(self, item, name, tag=None):
        if not tag: tag = name
        value = getattr(item, tag)
        if hasattr(self, 'serialize_field_'+name):
            return getattr(self, 'serialize_field_'+name)(value)
        else:
            if value:
                return str(value)
            return ''

    def serialize(self, item):
        """Concatenate serialized values
        """
        values = [ item.text ]

        fields = [ f for f in self.parser.item_parser.fields
                if not self.ignore_hidden_fields or not f.startswith('_') ]

        # Prepend fields
        values = [ self.serialize_field(item, *f.split(':'))
                for f in fields
                if f not in self.fields_append ] + values

        # Append fields
        values += [ self.serialize_field(item, *f.split(':'))
                for f in fields
                if f in self.fields_append ]

        return " ".join([ v for v in values if v ])

    def write(self, fn, items=None):
        """Serialize every item from the parser to file line,
        see self.serialize() for details.
        """
        fp = open( fn, 'w+' )
        if not items:
            items = self.parser.items()
        for it in items:
            fp.write( self.serialize(it) )
            fp.write('\n')
        fp.close()
