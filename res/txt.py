import re

from script_mpe import log

import task


class AbstractTxtLineParser(object):
    """
    """
    fields = ()
    def __init__(self, raw, parser=None, **attrs):
        super(AbstractTxtLineParser, self).__init__()
        self._raw = t = raw.strip()
        self.attrs = attrs
        # Access to parent parser, if needed to bring session onto instance
        self.parser = parser
        # Parse fields
        for f in self.fields:
            t = getattr(self, 'parse_'+f)( t )
            if not hasattr(self, f):
                setattr(self, f, None)
        self.text = t
    def todict(self):
        d = dict(
                attrs=self.attrs,
                text=self.text,
                _raw=self._raw
            )
        for f in self.fields:
            d[f] = getattr(self, f)
        return d
    def __str__(self):
        return self.text
    def __repr__(self):
        return "%s(%r)" % ( self.__class__.__name__, self.text )

class AbstractTxtSegmentedRecordParser(AbstractTxtLineParser):
    section_key_re = re.compile(r"(^|\W|\ )([%s]+):(\ |$)" % (
        task.meta_tag_c ))
    def __init__(self, raw, **attrs):
        self.sections = {}
        super(AbstractTxtSegmentedRecordParser, self).__init__(raw, **attrs)
    def parse_sections(self, t):
        for sk_m in self.section_key_re.finditer(t):
            k = sk_m.group(2)
            if k not in self.sections:
                pass # log.warn("Duplicate section %s at line %i" % ( k,
                # self.attrs['doc_line'] ))
                continue
            self.sections[k] = sk_m.span()
        return t

class AbstractTxtRecordParser(AbstractTxtLineParser):
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
    end_c = r'(?=\ |$|[%s])' % task.excluded_c
    project_re = re.compile(r"%s\+([%s]+)%s" % (start_c, task.prefixed_tag_c, end_c))
    context_re = re.compile(r"%s@([%s]+)%s" % (start_c, task.prefixed_tag_c, end_c))
    def __init__(self, raw, **attrs):
        self.cites = []
        self.hrefs = []
        self.state = None
        self.dates = None
        self.contexts = []
        self.projects = []
        super(AbstractTxtRecordParser, self).__init__(raw, **attrs)
    def parse_hrefs(self, t):
        for href_m in self.href_re.finditer(t):
            href = self.parser.handle_href(href_m.group(1))
            self.hrefs.append(href)
        return t
    def parse_cites(self, t):
        cl = []
        for cite_m in self.cite_re.finditer(t):
            cite = self.parser.handle_cite(cite_m.group(1))
            self.cites.append(cite)
            cl.append(cite_m.span())
        cl.sort()
        cl.reverse()
        for sp in cl:
            t = t[:sp[0]]+t[sp[1]:]
        return t
    def parse_projects(self, t):
        c = []
        cl = []
        for m in self.project_re.finditer(t):
            if not m or not m.group(2): continue
            project = self.parser.handle_project(m.group(2))
            self.projects.append(project)
            cl.append(m.span())
        cl.sort()
        cl.reverse()
        for sp in cl:
            t = t[:sp[0]]+t[sp[1]:]
        self.projects = c
        return t
    def parse_contexts(self, t):
        c = []
        cl = []
        for m in self.context_re.finditer(t):
            if not m or not m.group(2): continue
            context = self.parser.handle_context(m.group(2))
            self.contexts.append(context)
            cl.append(m.span())
        cl.sort()
        cl.reverse()
        for sp in cl:
            t = t[:sp[0]]+t[sp[1]:]
        self.contexts = c
        return t
    def parse_state(self, t):
        #self.parser.handle_state
        if t.startswith("d "):
            self.state = 'completed'
            t = t[2:]
        elif self.creation_date:
            self.state = 'created'
        return t
    def parse_creation_date(self, t):
        m = self.dt_r.match(t)
        if m:
            self.creation_date = m.group(1)
            return t[sum(m.span()):]
        return t
    def parse_completion_date(self, t):
        m = self.dt_r.match(t)
        if m:
            self.completion_date = m.group(1)
            return t[sum(m.span()):]
        return t


class AbstractRecordIdStrategy(AbstractTxtLineParser):
    """
    Mixing for records to retrieve Id, working together with AbstractIdStrategy
    iface on container.
    """
    def __init__(self, raw, **attrs):
        self.record_id = None
        super(AbstractRecordIdStrategy, self).__init__(raw, **attrs)
        if self.record_id:
            self.parser.init_id(self)
    def parse_id(self, t):
        if not self.sections:
            return t
        # First section is id for item
        id_dsp = min([dsp for dsp, wid in self.sections.values()])
        for key, (dsp, wid) in self.sections.items():
            if id_dsp == dsp:
                self.record_id = key
        return t

class AbstractRecordReferenceStrategy(AbstractTxtLineParser):
    def __init__(self, raw, **attrs):
        self.references = {}
        super(AbstractRecordReferenceStrategy, self).__init__(raw, **attrs)
    def parse_refs(self, txt):
        return txt


class AbstractTxtListParser(object):
    item_parser = AbstractTxtRecordParser
    def __init__(self, be={}, apply_contexts=[]):
        assert isinstance(apply_contexts, list), apply_contexts
        super(AbstractTxtListParser, self).__init__()
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
            print store_name
    def load_file(self, fn):
        "Parse items from a file, yielding %s instances"
        line = 0
        self.doc_name = fn
        for itraw_str in open( fn ).readlines():
            itraw = itraw_str.decode('utf-8')
            line += 1
            itraw_ = itraw.strip()
            if not itraw_ or itraw_[0] == '#': continue
            it = self.parse(itraw, doc_name=fn, doc_line=line)
            for ctx in self.apply_contexts:
                if ctx not in it.contexts:
                    it.contexts.append(ctx)
            yield it
    def parse(self, txtitem, **attrs):
        return self.item_parser( txtitem, parser=self, **attrs )


class AbstractIdStrategy(AbstractTxtListParser):
    """
    By providing a 'records' attribute on the container, allow indexed access to
    items by Id. And for record parsers to check for existing reference.
    """
    item_parser= AbstractRecordIdStrategy
    def __init__(self, record_cites=False, **kwds):
        self.records = {}
        self.references = {}
        self.record_cites = record_cites
        super(AbstractIdStrategy, self).__init__(**kwds)
    def init_id(self, record):
        self.records[record.record_id] = record
    # TODO: no on-init ctx/prj/ref/cite handling yet. see AbstractTxtListParser.proc
    def handle_context(self, ctx):
        print self.__class__.__name__, 'handle_context', ctx
        return ctx
    def handle_project(self, project):
        return project
    def handle_href(self, href):
        return href
    def handle_cite(self, cite):
        if self.record_cites:
            self.references[cite] = None
        else:
            assert ( cite in self.records or cite in self.references ), "Invalid citation: %s" % cite
        return cite
    def handle_ref(self, refid):
        assert ( refid in self.records or refid in self.references ), "Invalid reference: %s" % refid
        return refid


