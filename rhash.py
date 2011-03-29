import hashlib, os, sys

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

class Checksum(Base):
    __tablename__ = 'chk'
    id = Column(Integer, primary_key=True)
    sha1 = Column(String(32), index=True, unique=True, nullable=False)
    md5 = Column(String(32), index=True, unique=True, nullable=False)

resource_checksum = Table('path_checksum', Base.metadata,
    Column('path_ida', ForeignKey('path.id')),
    Column('chk_idb', ForeignKey('chk.id'))
)
Checksum.paths = relationship(Path, secondary=resource_checksum,
        backref='checksums')

def initialize(dbref):
    engine = create_engine(dbref)#, echo=True)
    Base.metadata.create_all(engine)  # issues DDL to create tables
    session = sessionmaker(bind=engine)()
    return session

### Commands
def add_files(session, dir):
    for root, files, dirs in os.walk(dir):
        for f in files:
            fpath = os.path.join(root, f)
            add_file(session, fpath)

def add_file(session, fpath):
    path = Path.all().filter(Path.ref == fpath).get()
    if not path:
        path = Path(ref=fpath)
        session.add(path)
    else:
        checksum = Checksum.all().filter()

    data = open(fpath).read()
    sha1sum = hashlib.sha1(data).hexdigest()
    md5sum = hashlib.md5(data).hexdigest()
    checksum = Checksum.all().filter(Checksum.sha1 == sha1sum).get()
    # TODO
    if checksum:
        if not checksum.md5:
            checksum.md5 = md5sum
    checksum = Checksum.all().filter(Checksum.md5 == md5sum).get()
    if checksum:
        if not checksum.sha1:
            checksum.sha1 = sha1sum

### Main entry point
def main():
    pwd = os.getcwd()
    volume = confparse.find_parent('volume.db', pwd)
    if not volume:
        return
    #dbref = "sqlite:///" + os.path.abspath(volume)
    volumeid = make_id(os.path.dirname(volume))
    dbref = 'mysql://scrow-user:p98wa7txp9zx@robin/'+volumeid
    session = initialize(dbref)
    add_files(session, pwd)

if __name__ == '__main__':
    main()

