#!/usr/bin/python
import hashlib, os, sys

import sqlalchemy
from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
        ForeignKey, Table, Index
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker
from docutils.nodes import make_id

import confparse


config = confparse.get_config('cllct.rc')
"Find configuration file. "

settings = confparse.yaml(*config)
"Parse settings. "

### Database schema
Base = declarative_base()

class Path(Base):
    __tablename__ = 'path'
    id = Column(Integer, primary_key=True)
    ref = Column(String(255), index=True, unique=True)

    def __str__(self):
        return """`%s <%s>`""" % (self.id, self.ref)

resource_checksum = Table('path_checksum', Base.metadata,
    Column('path_ida', ForeignKey(Path.id)),
    Column('chk_idb', ForeignKey('chk.id'))
)
class Checksum(Base):
    __tablename__ = 'chk'
    id = Column(Integer, primary_key=True)
    sha1 = Column(String(32), index=True, unique=True, nullable=False)
    md5 = Column(String(32), index=True, unique=True, nullable=False)

    def __str__(self):
        return """    :MD5: %s
    :SHA1: %s

""" % (self.md5, self.sha1)

    paths = relationship(Path, secondary=resource_checksum,
        backref='checksums')

def initialize(dbref):
    engine = create_engine(dbref)#, echo=True)
    Base.metadata.create_all(engine)  # issues DDL to create tables
    session = sessionmaker(bind=engine)()
    return session

### Commands
def add_files(session, dir):
    for root, dirs, files in os.walk(dir):
        for f in files:
            fpath = os.path.join(root, f)
            add_file(session, fpath)

def add_file(session, fpath):
    if not os.path.islink(fpath):
        assert os.path.isfile(fpath), fpath
    else:
        if not os.path.isfile(fpath):
            print >>sys.stderr, "Broken link: %s" % fpath
            return

    try:
        path = session.query(Path).filter(Path.ref == fpath).one()
    except sqlalchemy.orm.exc.NoResultFound, e:
        path = Path(ref=fpath)
        session.add(path)

    data = open(fpath).read()
    sha1sum = hashlib.sha1(data).hexdigest()
    md5sum = hashlib.md5(data).hexdigest()

    checksum = None
    if path:
        checksums = session.query(Checksum).join('paths').filter(Path.ref == fpath).all()
        if checksums:
            assert len(checksums) == 1, checksums
            checksum = checksums.pop()

    new = False
    if not checksum:
        try:
            checksum = session.query(Checksum).filter(Checksum.sha1 == sha1sum).one()
        except sqlalchemy.orm.exc.NoResultFound, e:
            pass

        try:
            checksum = session.query(Checksum).filter(Checksum.md5 == md5sum).one()
        except sqlalchemy.orm.exc.NoResultFound, e:
            pass

        if not checksum:
            new = True
            checksum = Checksum(sha1=sha1sum, md5=md5sum)

    if not checksum.md5:
        checksum.md5 = md5sum
    elif checksum.md5 != md5sum:
        print "MD5 sum has changed. "

    if not checksum.sha1:
        checksum.sha1 = sha1sum
    elif checksum.sha1 != sha1sum:
        print "SHA1 sum has changed. "

    if path not in checksum.paths:    
        checksum.paths.append(path)

    if new:
        print path#checksum, path

    session.add(checksum)
    session.commit()


### Main entry point
def parse_args():
    return sys.argv[1:], None #TODO

def main():
    pwd = os.getcwd()
    if sys.argv[1:]:
        args, opts = parse_args()
        #cmdid == args.pop(0)
        #if cmdid == 'init':
        #    pass
        #    return
        #elif cmdid == 'list':
        #    return
        #else:
        pwd = args.pop()

    volume = confparse.find_parent('.cllct/volume', pwd)
    if not volume:
        print >>sys.stderr, "Not on a volume: %s" % pwd
        return
    dbref = "sqlite:///%s/hash.db" % os.path.abspath(volume) # that's right, 4 backslashes
    volumeid = make_id(os.path.dirname(os.path.dirname(volume)))
    print "Found volume `%s <%s>` " % (volumeid, volume)
    #dbref = 'mysql://scrow-user:p98wa7txp9zx@robin/'+volumeid
    print "Opening hash index '%s'" % dbref
    session = initialize(dbref)
    add_files(session, pwd)

if __name__ == '__main__':
    main()

