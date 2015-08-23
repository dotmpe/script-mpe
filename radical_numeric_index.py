
"""
Simple comment storage API. With numeric ID's.

For each comment a record with a generated ID and digest is kept.

Comments without ID may match by identity to an existing record,
or are inserted as new records.

The identity is determined by SHA1 sum. Each record is stored once, 
ie. all recorded digests are distinct, unique values. The same restriction
applies to the numeric ID.

Comments queries with ID should match to an existing record. If the hash digests
differs, the record shall be updated to reflect the new value. The old digest is
discarded.

FIXME:
    Could record the history for each comment by listing all historical digests.


File Changelog
---------------
2011-04-30
    Initial version of service component.

"""

import hashlib

from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index
from sqlalchemy.ext.declarative import declarative_base



Base = declarative_base()

class Comment(Base):
    __tablename__ = 'document_embedded_comments_tinyid'
    numid = Column(Integer, primary_key=True)
    comment = Column(Text, index=True)
    comment_hash = Column(String(32), index=True, unique=True)


# TODO:1:
def comment(dbsession, comment, numid=None):
    comment_hash = hashlib.md5(comment).hexdigest()

    if numid:
        comments = session.query(Comment).filter(Comment.numid == numid).all()
        unique_hash_check = session.query(Comment).filter(Comment.comment_hash == comment_hash).all()
    else:
        comments = session.query(Comment).filter(Comment.comment_hash == comment_hash).all()

    if comments:
        if len(comments) > 1:
            pass
        if numid:
            if comments[0].comment_hash != comment_hash:
                pass # comment update
            else:
                pass # nothing to do
                return numid
        else:
            # found comment
            return comments[0].numid
    else:
        # no match, insert
        new_comment = Comment(comment=comment, comment_hash=comment_hash)
        session.add(new_comment)
        print new_comment.numid
        return new_comment.numid


def new_issue(tag, description):
# TODO
    print ('New', tag, description,)

def update_issue(tag, iid, description):
# TODO
    print ('Updated', tag, iid, description,)

