import os
import re
import base64


import redis
import uriref
from hashids import Hashids
import shortuuid

import mb


hashids = Hashids(salt="this is my salt")

prefixed_tag_c = mb.value_c
meta_tag_c = mb.value_c

re_issue_id = '[0-9a-z\/\.:;\-_]+'
re_issue_id_match = '\s*\\b%s('+re_issue_id+'[\:\s]+)\ *'

re_scheme = re.compile('[A-Za-z_][A-Za-z0-9_-]+')
re_numpath = re.compile('[0-9]+(\.[0-9]+)*\.?')

# NOTE: 2 chars would be the minimal for a tag or else it could match '-'
# 3 or 4 is more reasonable
re_tag_id = re.compile( r'\b[%s]{3,}\b%s[\:\s]*' % ( mb.capnumref_c, re_issue_id ) )

def parse_tags(txt):
    for m in re_tag_id.finditer(txt):
        yield txt[slice(*m.span())].strip(mb.excluded_c+' ')

seitag_todotxt_map = {
    'FIXME': '(C)', # tasks-ignore
    'TODO': '(D)', # tasks-ignore
    'XXX': '(F)' # tasks-ignore
}


class Task(object):
    def __init__(self):
        self.id = None
        self.group_id = None
        self.priority = None
        self.description = None


class TodoListParser(object):
    """
    "XXX: alt. syntax to TODOtxt? (res/todo.py)"

    """

    def __init__(self):
        self.list = {}

    def parse(self, fn):
        for todo in open( fn ).readlines():
            self.parse_todo(todo.strip('\n\r'))

    def parse_todo(self, item):
        if len(item) > 1 and item[1] == ' ':
            key = item[0]
            if key in '.#':
                new_key = shortuuid.ShortUUID().random(length=13)
                self.list[key] = item[2:]
                #redis.set(new_key, item[2:])
                pass # local or global
            elif key in "-+*":
                pass # user-defined list
        else:
            if not item.strip():
                return
            fields = item.split(' ')
            if re_scheme.match(fields[0]):
                uri = fields[0]
                print uriref.URIRef(uri)
                #print base64.b64encode(uri)
            elif re_numpath.match(fields[0]):
                nums = map(int, fields[0].strip('.').split('.'))
                id = hashids.encode(*nums)
                numbers = hashids.decode(id)
                print id, fields[0]
                #print base64.b64encode(fields[0])
            else:
                raise Exception("Unrecognized ID: %r" % fields[0])


default_redis = dict(host='localhost', port=6379, db=0)

class RedisSEIStore(object):
    """
    Keys::

        <prefix><sep><tag><sep>'length'
        <prefix><sep><tag_id><sep>'text'
        <prefix><sep><tag_id><sep>'comments' a set with all comment-ids

    """
    def __init__(self, tracker_tag, prefix='', sep='-',
            tag_id_pattern='%()s%(key_sep)s%()s', key_sep=':',
            server=default_redis):
        self.prefix = prefix
        self.key_sep = key_sep
        self.tag = tracker_tag
        self.sep = sep
        self.tag_id_format = "%s"+self.sep+"%i"
        self.tag_id_pattern = re.compile("%s%s[0-9]+" % ( self.tag, self.sep ))
        self.r = redis.StrictRedis(**server)
    def key_for(self, *args):
        args = list(args)
        if self.prefix:
            args = [ self.prefix ]+args
        return self.key_sep.join(args)
    def tag_id_for(self, key):
        """Remove prefix, then match with tag-id pattern to return without any
        key suffix parts."""
        m = self.tag_id_pattern.match( self.key[len(self.prefix+self.key_sep):] )
        return key[slice(*m.span())]
    def init(self):
        self.r[self.key_for('length')] = 0
    def __len__(self):
        k = self.key_for('length')
        return self.r.get(k)
    def __contains__(self, tag_id):
        k = self.key_for(tag_id, 'text')
        return self.r.exists(k)
    def __iter__(self):
        m = self.key_for(self.tag+'*')
        for key in self.r.scan_iter(m):
            yield key
    def find_link(self, comment_id):
        k = self.key_for('comment', comment_id)
        p = self.key_for(self.tag+'*:comments')
        for m in self.r.scan_iter(p):
            if list(self.r.sscan(m, k)):
                yield self.issue_tag_for(self, m)
    def new_issue(self, text):
        nr = self.r.incr(self.key_for('length'))
        return self.tag_id_format % ( self.tag, nr )
    def new_comment(self, issue_id, tag, id_len=9):
        newid = base64.urlsafe_b64encode(os.urandom(id_len))
        return "%s:%s" % ( tag, newid )
