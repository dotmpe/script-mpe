"""
File parser for todo.txt format.
"""
import re
import os
import base64
import uriref

from . import mb
from . import task
from . import txt
from . import txt2



### Todo Lists

class TodoListItemParser(
    txt2.AbstractTxtLineParserRegexFields,
    txt2.AbstractTxtLineParser,
):
    fields = (
        "completed:completed::1",
        "uriref:urls::0",
        "sections:sections::0",
    )

    sections_r = r"(^|(?<=\W|\ ))([%s]+):(\ |$)" % ( mb.value_c )
    completed_r = r"^x(\ )"
    uriref_r = r"(^|(?<=\W|\ ))<([^\ ]+)>(\ |$)"

    def __init__(self, *args, **kwds):
        self.field_names.update(dict(
            sections= (self.sections_r, unicode, 0),
            completed= (self.completed_r, unicode, 0),
            urls= (self.uriref_r, uriref.URIRef, 2)
        ))
        super(TodoListItemParser, self).__init__(*args, **kwds)
"""
    def parse_fieldargs_completed(self, text, onto, name, descr, *args):
        print(123, text, onto, name, descr, args)

    def parse_fieldargs_sections(self, text, onto, name, descr, *args):
        t = text
        for sk_m in self.sections_re.finditer(t):
            k = sk_m.group(2)
            if k not in self.sections:
                log.warn("Duplicate section %s at line %i" % ( k,
                    self.attrs['doc_line'] ))
                continue
            self.sections[k] = sk_m.span()
        return t
"""


class TodoListParser(
    txt2.AbstractTxtListParser
):
    item_parser = TodoListItemParser
    item_builder = txt2.SimpleTxtLineItem



class TodoTxtTaskParser(txt.AbstractTxtRecordParser_Old):

    """
    Split up todo.txt line into parts, and clean-up description.
    All parts, except projects and contexts are removed.
    The non-std part `issue-id` is a leading tag+':' field.
    """

    fields = ("completed priority creation_date completion_date"\
        " projects contexts attrs hold issue_id").split(" ")
    prio_prefix_r = re.compile("^\s*\(([A-F])\)\ |$")
    prj_r = re.compile(r"%s\+([%s]+)%s" % (mb.start_c, task.prefixed_tag_c, mb.end_c))
    ctx_r = re.compile(r"%s@([%s]+)%s" % (mb.start_c, task.prefixed_tag_c, mb.end_c))
    meta_r = re.compile(r"%s([%s]+):([%s]+)%s" % (mb.start_c,
        task.meta_tag_c, mb.value_c, mb.end_c ))
    issue_id_r = re.compile(r"%s([%s]+):%s" % (mb.start_c, task.meta_tag_c, mb.end_c))

    def __init__(self, raw, **attrs):
        super(TodoTxtTaskParser, self).__init__(raw, **attrs)
        self.tags = list(task.parse_tags(" %s ." % raw))
    def parse_priority(self, t, attr):
        m = self.prio_prefix_r.match(t)
        setattr(self, 'priority', None)
        if m:
            self.priority = m.group(1)
            return t[sum(m.span()):]
        return t
    def parse_projects(self, t, attr):
        p = []
        for m in self.prj_r.finditer(t):
            if not m or not m.group(2): continue
            p.append(m.group(2))
        self.projects = p
        return t
    def parse_contexts(self, t, attr):
        c = []
        for m in self.ctx_r.finditer(t):
            if not m or not m.group(2): continue
            c.append(m.group(2))
        self.contexts = c
        return t
    def parse_attrs(self, t, attr):
        a = {}
        for m in self.meta_r.finditer(t):
            if not m or not m.group(2): continue
            v = m.group(3)
            if v.isdigit():
                v = int(v)
            a[m.group(2)] = v
        self.attrs.update(a)
        return self.meta_r.sub('', t)
    def serialize_attrs(self):
        return " ".join([ "%s:%s" % i for i in self.attrs.items() ])
    attrs_str = property(serialize_attrs, parse_attrs)
    def parse_hold(self, t, attr):
        self.hold = t.endswith("[WAIT]")
        if self.hold:
            return t[:-6]
        return t
    def parse_completed(self, t, attr):
        v = t.startswith("x ")
        setattr(self, attr, v)
        if v:
            return t[2:]
        return t
    def parse_issue_id(self, t, attr):
        m = self.issue_id_r.match(t)
        if m and m.group(2):
            self.issue_id = m.group(2)
        return t
    def get_src_id(self):
        a = self.attrs
        for ak in 'src_name src_line'.split(' '):
            if not ak in a or not a[ak]:
                return
        return "%(src_name)s:%(src_line)s" % a
    src_id = property(get_src_id)
    def get_doc_id(self):
        a = self.attrs
        for ak in 'doc_name doc_line'.split(' '):
            if not ak in a or not a[ak]:
                return
        return "%(doc_name)s:%(doc_line)s" % a
    doc_id = property(get_doc_id)
    def todotxt(self):
        t = self.text
        """
        if self.creation_date:
            t = self.creation_date+' '+t
        if self.completed:
            if self.completion_date:
                t = self.completion_date+' '+t
            t = 'x '+t
        elif self.priority:
            t = "(%s) "+t
        """
        if self.attrs:
            t += ' '+self.attrs_str
        if self.hold:
            t += ' [WAIT]'
        return t
    def get_id(self):
        return self.attrs['_id']
    id = property(get_id)
    def __repr__(self):
        if '_id' in self.attrs:
            args = ( self.id, )
        else: args = ( "", )
        args += ( self.doc_id, "", #self.issue_id,
                self.src_id, hash(self) )
        return "TodoTxtTaskParser:%s;%s;%s;%s;<#%x>" % args
    def __str__(self):
        return self.todotxt()


class TodoTxtParser(dict):
    """
    Arguments:
        tags
            List of primary tag followed by secondary tags.
    """
    # TODO: still uses old parser
    def __init__(self, tags=[]):
        UserDict.__init__(self)
        self.tags = tags
        self.dirty = []
        self.issues = {}
        # TODO: SCRIPT-MPE:2 should really not be using docid. srcid needs refinement
        self.doc_ids = {}
        self.src_ids = {}
        self.tag_ids = {}
    def commit(self, tasks_file):
        """
        XXX: append new/dirty task items to list file
        """
        for k in self.dirty:
            ttt = self[k]
            txt = ttt.todotxt()
            # TODO: SCRIPT-MPE:2 replace doc line, and also have format for src line
            # for now append to storage doc only
            #if ttt.doc_id:
            #    fn = ttt.attrs['doc_name']
            open(tasks_file, 'a+').write(txt+'\n')
    def load(self, fn):
        for i, l in enumerate(open(fn).readlines()):
            yield self.parse(l, src_name=fn, src_line=i+1)
    def parse(self, todotxtitem, id_len=9, **attrs):
        ttt = TodoTxtTaskParser( todotxtitem, **attrs )
        if hasattr(ttt, 'issue_id'):
            tid = ttt.issue_id
        elif hasattr(ttt, 'item_id'):
            tid = ttt.item_id
        elif ttt.src_id: tid = ttt.src_id
        elif ttt.doc_id: tid = ttt.doc_id
        else: tid = base64.urlsafe_b64encode(os.urandom(id_len))
        self[tid] = ttt
        ttt.attrs['_id'] = tid
        if ttt.doc_id:
            self.doc_ids[ttt.doc_id] = tid
        self.src_ids[ttt.src_id] = tid
        for tag in ttt.tags:
            if tag not in self.tag_ids:
                self.tag_ids[tag] = []
            self.tag_ids[tag].append( tid )
        return ttt
    def __len__(self):
        return len(self.issues.keys())
    def __iter__(self):
        return iter(self.issues)
    def __contains__(self, key):
        return key in self.issues
    def __getitem__(self, key):
        return self.issues[key]
    def __setitem__(self, key, value):
        self.issues[key] = value
    def new_issue(self, text, **attrs):
        ttt = self.parse(text, **attrs)
        return ttt.attrs['_id']
    def new_comment(self, issue_id, tag, text='', id_len=0):
        newid = base64.urlsafe_b64encode(os.urandom(id_len))
        self[issue_id].text += ' %s-%s' %(tag, newid)
        if text:
            self[issue_id].text += ' '+text
        return newid
    def tagid_exists(self, tagid):
        if tagid in self:
            return True
        elif tagid in self.src_ids:
            return True
        elif tagid in self.doc_ids:
            return True
        elif tagid in self.tag_ids:
            return True
