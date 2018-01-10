# TODO: res.txt storage
from __future__ import print_function
from pprint import pformat, pprint


#tracked = 0
tracker_index = {}
filename = 'todo.txt'


def init(rc, opts):
    global tracker_index
    tracker_index = {}
    filename = opts.todotxt_store


def lists(tag=None):
    return tracker_index.keys()


def keep(iid, o):
    global tracker_index

    tracker_index[ iid ] = dict( embedded=o )


def globalize(iid, o):
    global tracker_index

    if iid not in tracker_index:
        keep(iid, o)
    return tracker_index[iid]


def new(tag, o):
    #print('New '+tag+' '+pformat(o))
    pass


def update(tag, iid, o):
    #print('Updated '+tag+' '+iid+' '+pformat(o))
    pass
