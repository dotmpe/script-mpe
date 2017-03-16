import re
import base64


import redis
import uriref
from hashids import Hashids
import shortuuid


hashids = Hashids(salt="this is my salt")

scheme = re.compile('[A-Za-z_][A-Za-z0-9_-]+')
numpath = re.compile('[0-9]+(\.[0-9]+)*\.?')


priorities = {
        'A': '',
        'B': '',
        'C': '',
        'D': '',
        'E': '',
        'F': ''
}
seitag_todotxt_map = {
    'FIXME': '(C)',
    'TODO': '(D)',
    'XXX': '(F)'
}
class Task(object):
    def __init__(self):
        self.id = None
        self.group_id = None
        self.priority = None
        self.description = None


class TodoTxtParser(object):
    def __init__(self):
        pass

    def parse(self, fn):
        for todo in open( fn ).readlines():
            self.parse_todo(todo)

    def parse_todo(self, todotxtitem):
        print todotxtitem


class TodoListParser(object):
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
            if scheme.match(fields[0]):
                uri = fields[0]
                print uriref.URIRef(uri)
                #print base64.b64encode(uri)
            elif numpath.match(fields[0]):
                nums = map(int, fields[0].strip('.').split('.'))
                id = hashids.encode(*nums)
                numbers = hashids.decode(id)
                print id, fields[0]
                #print base64.b64encode(fields[0])
            else:
                raise Exception("Unrecognized ID: %r" % fields[0])


