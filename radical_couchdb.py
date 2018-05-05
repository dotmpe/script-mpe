"""
Registered with radical `services` if configured.
"""

tracked = 0
tracker_index = {}


def lists(tag=None):
    return tracker_index.keys()

def keep(iid, o):
    tracker_index[ iid ] = dict( embedded=o )

def globalize(iid, o):
    global tracker_index, tracked
    if iid not in tracker_index:
        keep(iid, o)
    return tracker_index[iid]

def new(tag, o):
    global tracker_index, tracked
    tracked += 1
    iid = '%s:%i'%(tag, tracked)
    keep(iid, o)
    return tracker_index[iid]

def update(tag, iid, o):
    raise NotImplementedError("couch update")
