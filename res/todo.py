import re
import os
import base64

# local
import task



class TodoTxtTask(object):

    """
    Split up todo.txt line into parts, and clean-up description.
    All parts, except projects and contexts are removed.
    The non-std part `issue-id` is a leading tag+':' field.
    """
    fields = ("completed priority creation_date completion_date"\
        " projects contexts attrs hold issue_id").split(" ")
    prio_prefix_r = re.compile("^\s*\(([A-F])\)\ |$")
    dt_r = re.compile("^\s*([0-9]{4}-[0-9]{2}-[0-9]{2})\ |$")
    start_c = r'(^|\W)'
    end_c = r'(?=\ |$|[%s])' % task.excluded_c
    prj_r = re.compile(r"%s\+([%s]+)%s" % (start_c, task.prefixed_tag_c, end_c))
    ctx_r = re.compile(r"%s@([%s]+)%s" % (start_c, task.prefixed_tag_c, end_c))
    meta_r = re.compile(r"%s([%s]+):([%s]+)%s" % (start_c,
        task.meta_tag_c, task.value_c, end_c ))
    issue_id_r = re.compile(r"%s([%s]+):%s" % (start_c, task.meta_tag_c, end_c))

    def __init__(self, raw, **attrs):
        self._raw = t = raw.strip()
        self.attrs = attrs
        for f in self.fields:
            t = getattr(self, 'parse_'+f)( t )
            if not hasattr(self, f):
                setattr(self, f, None)
        self.text = t
    def parse_priority(self, t):
        m = self.prio_prefix_r.match(t)
        if m:
            self.priority = m.group(1)
            return t[sum(m.span()):]
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
    def parse_projects(self, t):
        p = []
        for m in self.prj_r.finditer(t):
            if not m or not m.group(2): continue
            p.append(m.group(2))
        self.projects = p
        return t
    def parse_contexts(self, t):
        c = []
        for m in self.ctx_r.finditer(t):
            if not m or not m.group(2): continue
            c.append(m.group(2))
        self.contexts = c
        return t
    def parse_attrs(self, t):
        a = {}
        for m in self.meta_r.finditer(t):
            if not m or not m.group(2): continue
            a[m.group(2)] = m.group(3)
        self.attrs.update(a)
        return self.meta_r.sub('', t)
    def serialize_attrs(self):
        return " ".join([ "%s:%s" % i for i in self.attrs.items() ])
    attrs_str = property(serialize_attrs, parse_attrs)
    def parse_hold(self, t):
        self.hold = t.endswith("[WAIT]")
        if self.hold:
            return t[:-6]
        return t
    def parse_completed(self, t):
        self.completed = t.startswith("x ")
        if self.completed:
            return t[2:]
        return t
    def parse_issue_id(self, t):
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
        if self.creation_date:
            t = self.creation_date+' '+t
        if self.completed:
            if self.completion_date:
                t = self.completion_date+' '+t
            t = 'x '+t
        elif self.priority:
            t = "(%s) "+t
        if self.attrs:
            t += ' '+self.attrs_str
        if self.hold:
            t += ' [WAIT]'
        return t


class TodoTxtParser(object):
    """
    Arguments:
        tags
            List of primary tag followed by secondary tags.
    """
    def __init__(self, tags=[]):
        self.tags = tags
        self.dirty = []
        self.issues = {}
    def commit(self):
        for k in self.dirty:
            ttt = self[k]
            txt = ttt.todotxt()
            # TODO replace doc line, and also have format for src line
            # for now append to storage doc only
            if ttt.doc_id:
                fn = ttt.attrs['doc_name']
            else:
                fn = self.doc_name
            open(fn, 'a+').write(txt+'\n')
    def load(self, fn):
        line = 0
        self.doc_name = fn
        for todoraw in open( fn ).readlines():
            line += 1
            todoraw_ = todoraw.strip()
            if not todoraw_ or todoraw_[0] == '#': continue
            ttt = self.parse(todoraw, doc_name=fn, doc_line=line)
            yield ttt
    def parse(self, todotxtitem, id_len=9, **attrs):
        ttt = TodoTxtTask( todotxtitem, **attrs )
        if ttt.issue_id: tid = ttt.issue_id
        elif ttt.src_id: tid = ttt.src_id
        elif ttt.doc_id: tid = ttt.doc_id
        else: tid = base64.urlsafe_b64encode(os.urandom(id_len))
        self[tid] = ttt
        ttt.attrs['_id'] = tid
        return ttt
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
