"""
res.txt - abstract bases and mixins dealing with parsing lined-based content.

list-parser handles files and streams, and tracking context for items extracted
via line-parser. All docs inline, with interfaces given to allow for more
structured documentation.

Related modules:
  res.lst - misc. types of simple lists from plain-text: dates, numbers, URL's
  res.todo - TODO.txt format on steriods
  res.task - data sync and events for res.txt items
  res.txt - this file, interfaces and abstract types

Further higehr level docs are in `res`, in the section on plain text items
and lists.
"""
import os
import re
from UserDict import UserDict
from UserList import UserList

import zope.interface
from zope.interface import Interface, Attribute, implements, classImplements

from script_mpe import log
import tp
import dt
import mb
import task



re_idref = re.compile('([A-Z]+):')

### Interfaces with docs for line- and list-parser base

class ITxtLineParser(zope.interface.Interface):

    """
    This type should be tasked with delegating per-line parser handling to
    subtype method implementions. It specifies how to define the fields the
    parser handles, how to access the parent list-parser and how to ID and
    distinguish itself from other ITxtLineParser type variants.

    Extraction is performed by to-be defined methods, on other types.
    AbstractTxtLineParser handles the mapping of each field spec to the
    parser method, it passes the mutated text through each field parser,
    and has some helpers to store extracted data. Via the parser attribute there
    is access to each immutable line context and other things.

    Since other types provide the parser handler implementations, the way the
    items contain extracted data pieces is their concern as well. For example,
    in case of a simple parser with no item_builder the items are actually just
    parser contexts for each source line. In that case it would make sense for
    all extracted fields to go to new keys in the context dict. Whereas in many
    practical cases attributes, other types of indexed access or even complex
    schemes involving methods, flows and roundtrips may be required.
    """
    fields = Attribute("The names, or field specs in order of extraction")
    parser = Attribute("A reference to the list-parser, e.g. to handle field values or record instances")
    index = Attribute("Index to the last or current list-item processed")
    item = Attribute("The last or current list-item from list-parser")
    context = Attribute("The last or current line-context from the list-parser")
    default_field_handler_prefix = Attribute("A identifier for the form of field-parser used on the lines")


class ITxtListParser(zope.interface.Interface):

    """
    """

    item_parser = Attribute("The type or generator of the item-parser class")
    parser = Attribute("A reference to the item parser instance")
    item_builder = Attribute("The type or factory for item instances")
    line_contexts = Attribute("Listparser instance context data for each line")
    items = Attribute("Line-number indexed access to parsed items")


### Abstract line-parser base

class AbstractTxtLineParser(object):

    """
    The base class for text.list line-parsers, this has no actual text parsing
    at all but defines the basic structure with parser context access and flow.

    This does nothing but given a line-number and -parser, iterate over each
    field spec and call the abstract run_field_parse method for the current
    line. For further docs refer to ITxtListParser doc.

    Each fieldspec is a ':' separated string, which is split, passed along with
    the text and any onto-object during handler invocation. Other subtypes will
    need to provide for the run_field_parse impl. as well as all further
    handling of data to `onto.
    """

    fields = ()
    """
    Fields are <name>[:<args>...] specs of at least one ':' delimited part.
    """

    default_field_handler_prefix = 'parse_field'

    def __init__(self, list_parser, *args, **kwds):
        super(AbstractTxtLineParser, self).__init__()
        # Access to parent parser, if needed to bring session onto instance
        self.parser = list_parser
        self.field_handler_prefix = self.default_field_handler_prefix
        self._index = 0

    def field_names(self):
        for f in self.fields:
            f_ = f.split(':')
            yield f_[0]

    @property
    def index(self):
        return self._index

    @property
    def line(self):
        return self.parser.items[self._index][0]

    @property
    def rawdata(self):
        return self.parser.items[self._index][1]

    @property
    def text(self):
        return self.parser.items[self._index][2]

    @property
    def item(self):
        return self.parser.items[self._index][3]

    @property
    def context(self):
        return self.parser.line_contexts[self.line]

    def parse(self, txtitem, i, onto=None):

        """
        Parse fields from txtitem, run field-parsers in sequence with currently
        extracted text and data at onto instance.
        """

        t, self._index = txtitem.strip(), i

        # Parse fields
        for f in self.fields:
            t = self.run_field_parse(t, onto, *f.split(':'))

        return t.strip()

    def run_field_parse(self, text, onto, *args):
        """
        Field parser handles all instances of specified field in text line.
        Abstract method on AbstractTxtLineParser.
        """
        raise NotImplementedError(
                self.__class__.__name__, self.field_handler_prefix,
                repr(text), repr(onto), repr(args))

    def run_or_default(self, name, *args):
        """
        Helper to get parse_field* handler, with arg pass-through and default
        fallback for missing.
        """
        handler_name = '%s_%s' % (self.field_handler_prefix, name)
        if hasattr(self, handler_name):
            return getattr(self, handler_name)(*args)
        else:
            return getattr(self, self.field_handler_prefix)(*args)


### Concrete example on line-parser base

class ConcreteTxtLineParser(AbstractTxtLineParser):

    """
    This is more of a source-code example (for a simple res.txt line-parser
    base class, and using the default field_handler_prefix), than a practical
    parser.

    It has for a restrictive 1-part field-spec but with fall back to
    a default parse_field pass-through function for missing field handlers.
    """

    implements(ITxtLineParser)

    def run_field_parse(self, text, onto, method):
        return self.run_or_default(method, text, onto)

    def parse_field(self, text, onto):
        return text


### Abstract addons to line-parser base

class AbstractTxtLineParserTargetStrategy(object):

    """
    This adds concrete `onto` storage for AbstractTxtLineParser, but
    no run_field_parse.
    """

    access_type_alias = {
        's': 'ter',
        'k': 'key',
        'i': 'idx',
        'a': 'attr'
    }
    DEFAULT_ACCESS_TYPE = 'attr'

    def __init__(self, *args, **kwds):
        super(AbstractTxtLineParserTargetStrategy, self).__init__(*args, **kwds)
        self.default_access_type = self.DEFAULT_ACCESS_TYPE

    def get_attr_field(self, onto, name):
        return getattr(onto, name)
    def get_key_field(self, onto, name):
        return onto[name]
    def get_idx_field(self, onto, name):
        return onto[int(name)]
    def get_ter_field(self, onto, name):
        return getattr(onto, name)()

    def fetch_field(self, onto, at, name):
        return getattr(self, 'get_%s_field' % at)(onto, name)

    def set_attr_field(self, onto, name, value):
        setattr(onto, name, value)
    def set_key_field(self, onto, name, value):
        onto[name] = value
    def set_idx_field(self, onto, name, value):
        onto[int(name)] = value
    def set_ter_field(self, onto, name, value):
        getattr(onto, name)(value)

    def store_field(self, onto, at, name, value):
        getattr(self, 'set_%s_field' % at)(onto, name, value)

    def field_descriptor(self, onto, at, name):
        def get():
            return self.fetch_field(onto, at, name)
        def set(value):
            self.store_field(onto, at, name, value)
        for f in get, set:
            setattr(f, 'at', at)
            setattr(f, 'name', name)
        return get, set


class AbstractTxtLineParserFieldsStrategy(AbstractTxtLineParserTargetStrategy):

    """
    ~FieldsStrategy adds a concrete `run_field_parse` for AbstractTxtLineParser
    based on a three-part spec, and get/set descriptors provided for by
    ~TargetStrategy.

    This basic field strategy uses the 'parse_fields_*' signature for methods
    using this spec, to be distinguished from other res.txt list based parsers
    with different fieldspecs.
    """

    default_field_handler_prefix = 'parse_fields'

    def field_targets(self):
        for f in self.fields:
            f_ = f.split(':')
            if len(f_) > 2: yield f_[2]
            else: yield f_[0]

    def run_field_parse(self, text, onto, method, at, target):
        if not target: target = method
        if not at: at = self.default_access_type
        while at in self.access_type_alias:
            at = self.access_type_alias[at]

        descr = self.field_descriptor(onto, at, target)
        return self.run_or_default(method, text, descr)

    def parse_fields(self, text, descr):
        # current, new = descr
        raise NotImplementedError()


class AbstractTxtLineParserSimpleFieldArgsStrategy(AbstractTxtLineParserTargetStrategy):

    """
    ~SimpleFieldArgsStrategy adds concrete `run_field_parse` for
    AbstractTxtLineParser based on a simpler one or two-part spec with automatic
    switch and default-access between attribute and key-index based on provided
    `onto` instance and state.

    The extended handler function signature contains besides the text, the
    handlers own name again, along with get/set descriptor to onto, and onto
    reference itself to acces other fields. Furthermore fieldspec rest-parts
    are pass-though as the final arguments.
    """

    default_field_handler_prefix = 'parse_fieldargs'

    def field_map(self):
        for f in self.fields:
            f_ = f.split(':')
            if len(f_) > 1: yield f_[0], f_[1]
            else: yield f_[0], f_[0]

    def field_targets(self):
        for f in self.fields:
            f_ = f.split(':')
            if len(f_) > 1: yield f_[1]
            else: yield f_[0]

    def run_field_parse(self, text, onto, method, target, *args):
        if not target: target = method

        # Determine access-type to value by onto object type/state
        at = None
        if isinstance(onto, (dict, UserDict)):
            if target in onto:
                at = 'key'
        if isinstance(onto, (list, UserList)):
            at = 'idx'
        if not at and hasattr(onto, target):
            at = 'attr'
        if not at:
            if isinstance(onto, (dict, UserDict)):
                at = 'key'
            else:
                at = 'attr'
                if not hasattr(onto, target):
                    setattr(onto, target, None)

        descr = self.field_descriptor(onto, at, target)
        return self.run_or_default(method, text, onto, method, descr, *args)

    def parse_fieldargs(self, text, onto, name, descr, *args):
        # current, new = descr
        raise NotImplementedError()


class AbstractTxtLineParserRegexFields(AbstractTxtLineParserSimpleFieldArgsStrategy):

    """
    An abstract field parser handler for res.txt line-parser base, defines
    fields by named regex(es).

    Field specs correspond to a ~RegexFields.field_names entry, which specifies
    regex, constructor and optional regex groups to map match groups to constructor
    arguments.

    Additional field specs 3: cardinality and 4: symbol are taken in to
    prescribe handling of multiple regex matches, and deal with hiding of
    non-user attributes and machine data.
    Part 1: name is inherited from res.txt line-parser base,
    part 2: target from ~SimpleFieldArgsStrategy.
    """

    field_names = tp.typebuilders

    default_field_handler_prefix = 'parse_fieldargsre'

    def __init__(self, *args, **kwds):
        super(AbstractTxtLineParserRegexFields, self).__init__(*args, **kwds)
        self.init()

    def init(self):
        # Pre-compile regex patterns
        self.re_opts = (re.VERBOSE,)
        self._mb = {}
        for name, target, in self.field_map():
            if target not in self.field_names: target = name
            r = self.field_names[target][0]
            self._mb[name] = re.compile(r, *self.re_opts)

    # Private methods implementing the ~RegexFields addon

    def __fields(self, name, text):
        "Return generator for matches of given field name"
        return self._mb[name].finditer(text)

    def __nextfield(self, name, descr, cardinality, symbol):
        "Before setting new data"
        _get, _set = descr
        current = _get()
        if current == None:
            if cardinality > 1 or cardinality == 0:
                _set([])
        else:
            if cardinality == 1 or len(current) == cardinality:
                raise ValueError("Data instance exists for %s field" % name)

    def __fieldargs(self, *args):
        """
        "Get cardinality, whitespace mode and symbol width from fieldspec part,
        or give default.

        Cardinality may be int, or '*' for infinite, and defaults to 1.

        Symbol should be 0 to completely hide the symbols, 1 or more to specify
        a fixed width space or placeholder for the symbol, or is by default
        left empty to indicate the extracted fields are left as readable part
        in the text body.
        """
        cardinality, symbol = None, None

        if len(args)>0: cardinality = args[0]
        if cardinality == '*': return float('inf')
        if cardinality: cardinality = int(cardinality)
        else: cardinality = 1

        if len(args)>1: symbol = args[1]
        if symbol: symbol = int(symbol)

        return cardinality, symbol

    def __store(self, descr, name, match, cardinality, symbol):
        """
        Use get/set descriptor to update field name with values from match obj.
        Observes cardinality given as first rest-fieldspec, see __fieldargs.
        """
        get, set = descr
        if get.name in self.field_names: target = get.name
        else: target = name

        newtype, groups = self.field_names[target][1], self.field_names[target][2:]

        # Use current value as default for typebuilder in case of complex types
        current = None
        if cardinality > 1 or cardinality == 0: current = get()
        if groups:
            # Group numbers should provide typebuilder data tuple,
            # (key, val)'s for dict, items for list or one specific sub-match
            # for evey other type.
            data = tp.typebuilder_from_re(match, newtype, current, *groups)
        else:
            # Handle native and class types directly using entire match span,
            # no processing parts from regex match object
            data = tp.typebuilder(match.group(0), newtype, current)

        if cardinality > 1 or cardinality == 0:
            if data and data not in current:
                current.append(data)
        elif cardinality == 1:
            current = get()
            if data and data != current:
                set(data)

        span = match.span()
        if symbol != None:
            return span, symbol


    # Hook to ~FieldsStrategy dispatcher for sub-line field structures

    def parse_fieldargsre(self, text, onto, name, descr, *args):

        """
        Default line-parser field handler, for ~RegexFields.
        """

        cardinality, symbol = self.__fieldargs(*args)

        # Track parsed text, count for field name, and source spans for cut-list
        t, c, cl = text, 0, []

        # Find/parse data instances
        for field_m in self.__fields(name, t):
            c += 1

            # Track cardinality and/or prepare for new entry
            self.__nextfield(name, descr, cardinality, symbol)

            # Process match, return span for non-user readable or hidden data
            span_map = self.__store(descr, name, field_m, cardinality, symbol)
            if span_map:
                cl.append(span_map)

            if c == cardinality: break

        # For hidden parsed data, cut out spans. padd space if requested..
        cl.reverse()
        for sp, w in cl:
            t = t[:sp[0]]+(' '*w)+t[sp[1]:]

        # Return left over text
        return t




### Abstract list-parser base

class AbstractTxtListParser(object):

    """
    The base class for text.list file parsers has methods to parse and process
    one list of items and deal with parsed instances. Parsing is done in
    sequence by one line-parser instance.
    """

    item_parser = AbstractTxtLineParser
    "The line-parser class"

    item_builder = None
    "The item factory or type"

    # Initialize/reset parser

    def __init__(self, *args, **kwds):
        super(AbstractTxtListParser, self).__init__()
        self.init()

    def init(self):
        "Prime attributes with default settings"
        self.set_lineparser()
        self.line_contexts = {}
        self.items = []

    def set_lineparser(self, klass=None):
        "Create line-parser instance; if given klass change its type"
        if klass:
            self.item_parser = klass
        self.parser = self.item_parser(self)

    # Load from local resources

    def _get_fl_src(self, fspec):
        "Return a file-like with initial size and source-name"
        if hasattr(fspec, 'read'):
            _fl = fspec
            name = fspec.name
        else:
            _fl = open( fspec )
            name = fspec
        size = os.path.getsize(name)
        return _fl, size, name

    def load_file(self, fspec):

        """
        Parse items from a file, return generator from self.load
        """

        return self.load( *self._get_fl_src( fspec ))

    # Load lines, track parser context and instantiate items

    def load(self, src, src_size, src_name='<string>'):

        """
        Parse items from stream, yield instances from builder or line context
        """

        # TODO: extend parser context, some gate.content based parser with
        # offsets would be nice to refactor to.
        ctx_init = dict(index=0, line=0, doc_line=0, offset=0, doc_offset=0)

        reader = Reader(src, src_size, src_name)
        for itraw_str in reader.readlines():

            # Increment and prepare for new line, proc+skip for non-item lines
            ctx_init['line'] += 1
            ctx_init['doc_line'] += 1
            itraw = itraw_str.decode('utf-8').strip()
            if self._parse_non_item(itraw, ctx_init, reader):
                # Non-items are not yielded but may be stored in line_contexts
                # as comment, or XXX: further pre-/line-proc possible; for now store comments
                continue

            # Increment and prepare state for line with new item
            reader.update(ctx_init)
            ctx = ctx_init.copy()
            ctx.update(dict(
                _raw=itraw_str,
                index=self.next_index
            ))

            self.line_contexts[ctx['line']] = ctx
            assert len(self.items) == ctx['index']
            self.items.append((ctx['line'], itraw_str, None, None))

            # Parse line using context, then include
            text, it = self.parse(itraw, ctx)
            self.items[ctx['index']] = (ctx['line'], itraw_str, text, it)

            self.proc(it)
            yield it

            # XXX: use of byte-offset, without tracking character width or the
            # amount of raw whitespace stripped limits use. Again, see
            # gate.content and Scrow for stream resource deref. and demuxing.
            itraw_len = len(itraw_str)
            ctx_init['offset'] += itraw_len
            ctx_init['doc_offset'] += itraw_len

    def parse(self, txtitem, ctx):
        """
        Pass txtitem and index to line parser, but generate `onto` instance
        using item_builder factory if set. The `onto` instances put into
        context 'item' key, so they are accessible through list-parser.items
        as well the line-context.
        """
        if self.item_builder:
            # Concrete parser should map fields to instance attr/keys/indices
            ctx['item'] = it = self.item_builder(self.parser, ctx)
            text = self.parser.parse(txtitem, ctx['index'], it)
            return text, it
        else:
            # Concrete parser will need to map fields to parser context dict.
            text = self.parser.parse(txtitem, ctx['index'])
            return text, ctx

    def _parse_non_item(self, itbare, ctx, reader):
        "Preprocess on trimmed line, allows to mark as non-item and skip parser"
        line = ctx['line']
        if not itbare:
            return True
        if itbare[0] == '#':
            if itbare[0:2] == '# ': # Keep comments
                self.line_contexts[line] = ctx.copy()
                self.line_contexts[line]['comment'] = itbare[2:]
            else: # Replace directives
                params = itbare.split(' ')
                # XXX: Don't know if script_mpe has much of a resource resolver,
                # so deferring ID decl. to env vars
                fref = re_idref.sub(r'$\1/', params[1].strip('"'))
                fn = os.path.expanduser(os.path.expandvars( fref ))
                filext = os.path.splitext(fn)[1][1:]
                if filext in ( 'list', 'txt', 'tab' ):
                    reader.insert_src(*self._get_fl_src(fn))
                    if len(params) > 2:
                        reader.insert_suffix(' ' + ' '.join(params[2:]))
                else:
                    log.warn("Ignored non-list include: %s" % fn)

            return True

    def proc(self, item):
        """
            Final pass on the parser's result before yielding from parse
            function.
        """
        #self.load(it) TODO: move to todo or tasks module
        """
        for ctx in self.apply_contexts:
            if ctx not in it.contexts:
                it.contexts.append(ctx)
        """
        return item

    @property
    def next_index(self):
        return len(self.items)


class Reader:

    """
    A simple readline reader that works from a stack, for the parsers to use
    to consume files with includes.

    In addition allows simple line prefix/suffix parts.
    """

    def __init__(self, src, size, name):
        self.srcs = [ src ] # Stack of sources to read from
        self.sizes = [ size ]
        self.names = [ name ]
        self.prefixes = []
        self.suffixes = []

    def __len__(self):
        return self.sizes[0]

    @property
    def prefix(self):
        if self.prefixes:
            return self.prefixes[0]

    @property
    def suffix(self):
        if self.suffixes:
            return self.suffixes[0]

    @property
    def name(self):
        return self.names[0]

    def insert_src(self, handle, filesize, name):
        self.srcs.append(handle)
        self.sizes.append(filesize)
        self.names.append(name)

    def pop(self):
        self.srcs[0].close()
        self.srcs.pop(0)
        self.sizes.pop(0)
        self.names.pop(0)
        if self.suffixes: self.suffixes.pop(0)
        if self.prefixes: self.prefixes.pop(0)

    def readlines(self):
        while len(self.srcs):
            if self.srcs[0].tell() == self.sizes[0]:
                self.pop()
            else:
                line = self.srcs[0].readline()
                if line.strip():
                    if self.prefix: line = self.prefix+line
                    if self.suffix: line+=self.suffix
                yield line

    def update(self, ctx):
        if 'doc_name' not in ctx:
            ctx['doc_name'] = self.name
        elif ctx['doc_name'] != self.name:
            ctx['doc_name'] = self.name
            ctx['doc_offset'] = 0
            ctx['doc_line'] = 0

    def insert_suffix(self, suffix):
        self.suffixes.insert(0, suffix)

    def insert_prefix(self, prefix):
        self.prefixes.insert(0, prefix)


### Simple type for res.txt list-item instances

class SimpleTxtLineItem(object):
    "Used as an `onto` store, with mixed dict and attr access"
    def __init__(self, parser, ctx):
        self.parser = parser
        self.ctx = ctx
        self._index = ctx['index']
    @property
    def _raw(self):
        return self.parser.parser.items[self._index][1]
    @property
    def text(self):
        return self.parser.parser.items[self._index][2]
    def __str__(self):
        return "%s. %s" %( 1+self._index, self.text or repr(self._raw) )
    def __repr__(self):
        return "%s(%r)" % ( self.__class__.__name__, self.to_dict() )

    KEYS = "offset line index doc_name doc_line doc_offset".split(' ')
    def to_dict(self, keys=KEYS):
        d = dict( text=self.text )
        for k in keys:
            if k == '_raw':
                d[k] = self._raw
            elif k in self.ctx:
                d[k] = self.ctx[k]
        for f in self.parser.field_targets():
            assert f, f
            d[f] = getattr(self, f)
        return d
