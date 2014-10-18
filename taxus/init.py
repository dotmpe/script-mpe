from sqlalchemy.sql import sqltypes
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import create_engine, event, Column
from sqlalchemy.orm import sessionmaker
from sqlalchemy.engine import Engine

import zope.interface

from script_mpe import log
from confparse import yaml_load, Values
import iface
import out


# class-registry maps model name to type.
# Also accesible with Model._decl_class_registry
class_registry = {}
SqlBase = declarative_base(class_registry=class_registry)


@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    """
    XXX on connect, assume is SQLite and > 3.6.19 
    """
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

def get_session(dbref, initialize=False, metadata=SqlBase.metadata):
    engine = create_engine(dbref)#, encoding='utf8')
    #engine.raw_connection().connection.text_factory = unicode
    metadata.bind = engine
    if initialize:
        log.info("Applying SQL DDL to DB %s..", dbref)
        metadata.create_all()  # issue DDL create 
        log.note('Updated schema for %s to %s', dbref, 'X')
    session = sessionmaker(bind=engine)()
    return session
#   dbref='mysql://scrow-user:p98wa7txp9zx@sam/scrow'
#   engine = create_engine(dbref, encoding='utf8', convert_unicode=False)
#    engine = create_engine('sqlite:///test.sqlite')#, echo=True)

    #dbref = 'mysql://robin/taxus'
    #dbref = 'mysql://robin/taxus_o'

def configure_components():
    zope.interface.classImplements(str, iface.IPrimitive)
    zope.interface.classImplements(unicode, iface.IPrimitive)
    zope.interface.classImplements(int, iface.IPrimitive)
    #zope.interface.classImplements(dict, IPrimitive)
    zope.interface.classImplements(list, iface.IPrimitive)
    #zope.interface.classImplements(tuple, IPyTuple)

    from datetime import datetime
    zope.interface.classImplements(datetime, iface.IPrimitive)

    # register IFormatted adapters
    iface.registerAdapter(out.IDFormatter)
    #idem as registry.register([IID], IFormatted, '', IDFormatter), etc
    iface.registerAdapter(out.PrimitiveFormatter)

    iface.registerAdapter(out.NodeSetFormatter)
    iface.registerAdapter(out.NodeFormatter)
    
    iface.registry.register([iface.IPrimitive], iface.IFormatted, '', out.PrimitiveFormatter)

    # TODO iface.gsm.registerUtility( obj, iface.IReferenceResolver ) 



def pluck(attr, dicts):
    for d in dicts:
        yield attr in d and d[attr] or None

def get_default(key, d, default=None):
    return key in d and d[key] or default

def default(key, d, default=None):
    if key in d:
        return d[key]
    v = key in d and d[key] or default
    d[key] = v
    return v

### metadata to SA model unmarshalling

def extract_schema(meta):
    """
        TODO Simplify models subtree to JSON schema..
    """
    #assert meta['schema']['version']  ==  0.1

def extract_orm(meta, sql_base=None):
    """
    Run over all models. TODO Extract metadata to construct SA ORM types.
    """
    #assert meta['schema']['version']  ==  0.1
    if not sql_base:
        class_registry = {}
        sql_base = declarative_base(class_registry=class_registry)
        assert not hasattr(sql_base, 'registry'), sql_base.registry
        sql_base.registry = class_registry
        yield sql_base
    for model_meta in extract_listed_named(meta['schema']['models']):
        model = extract_model(model_meta, sql_base=sql_base)
        if hasattr(model, 'type') and model.type == 'abstract':
            pass
        yield model

def extract_model(model_meta, sql_base):
    model_type = default('type', model_meta)
    model_extends = default('extends', model_meta)
    model_table = default('table', model_meta)
    type_dict = dict(
            __tablename__ = model_table
        )

    model_mixins = default('mixins', model_meta, [])
    if model_mixins:
        model_mixins = extract_listed_names(model_mixins)
        print 'TODO mixins', model_mixins, sql_base.registry

    model_extends = default('extends', model_meta, [])
    if model_extends:
        # one of the model relations will need to express a one-to-one
        # relation to express which instance of extends to inherit from.
        print 'TODO extends', model_extends, sql_base.registry

    indices = extract_indices(model_meta)
    for field in extract_listed_named(model_meta['fields']):
        type_dict[field['name']] = extract_field(indices, field)
    if model_type != 'Abstract':
        return type(model_meta['name'], (sql_base,), type_dict)
    else:
        return Values(model_meta)

def extract_indices(model_meta):
    indices = Values(dict(
        normal= {}, # XXX normal index?
        unique= {},
        primary= None,
    ))

    model_indices = default('indices', model_meta, [])

    named_indices = extract_listed_named(model_indices, force=False)
    for index in named_indices:
        index_fields = list(extract_listed_names(index['fields']))
        assert isinstance(index_fields, list), index_fields
        index_name = default('name', index)
        index_type = default('type', index, 'normal')
        assert index_type in "normal primary unique"
        if not index_name:
            if index_type == 'primary':
                index_name = model_meta['table']+'_pk'
            else:
                index_name = '_'.join(pluck('name', index_fields))+(dict(
                    unique = '_unique',
                    normal = '_idx'
                )[index_type])
        if index_type == 'primary':
            assert not indices.primary, indices.primary
            indices.primary = list(pluck('name', index_fields))
        elif index_type == 'unique':
            for named in index_fields:
                name = named['name']
                assert name not in indices.unique, name
                indices.unique[name] = index_name
        elif index_type == 'normal':
            for named in index_fields:
                name = named['name']
                assert name not in indices.normal, name
                indices.normal[name] = index_name
    return indices


def extract_field(indices, field_meta):
    field_type = default('type', field_meta, 'String')
    field_extends = default('extends', field_meta)
    field_name = default('name', field_meta)
    field_len = get_default('len', field_meta)
    db_field = field_name
    assert field_type, field_name
    if field_type == 'relate':
        return Values(field_meta)
    else:
        col_type = getattr(sqltypes, field_type)
        kwds = {}
        if indices.primary == field_name or field_name in indices.primary:
            kwds['primary_key'] = True
        elif field_name in indices.unique:
            kwds['unique'] = True
        elif field_name in indices.normal:
            kwds['index'] = True
        if db_field == 'label':
            assert kwds['index']
        if field_len:
            try:
                col_type = col_type(field_len)
            except:
                raise Exception("%s does not accept length" % col_type)
        return Column(db_field, col_type, **kwds)


def extract_listed_named(meta_list, force=True):
    """
    Accept either dict or list, generate dicts
    that are assured to have a name property. In case of
    passing a dict in this name is copied over from meta_list
    if needed, or forced to be equal to the key. 
    In case meta_list is an actual list already, name should 
    be given. 
    """
    isList = isinstance( meta_list, list )
    for named in meta_list:
        if not isList:
            name = named
            named = meta_list[name]
            if 'name' not in named:
                named['name'] = name
            elif force:
                assert named['name'] == name, ( named['name'], 'is not', name )
        elif force:
            assert 'name' in named and named['name'], named
        yield named


def extract_listed_names(meta_list, sep=' ,', force=True):
    """
    Accept list or dict meta_list list extract_listed_named, but pre-parse
    if simple string is passed.
    """
    if isinstance(meta_list, basestring):
        raw = meta_list
        meta_list = []
        seps = list(sep) 
        while seps[:-1]:
            meta_list = meta_list.replace(seps.pop(0), seps[-1])
        for name in meta_list.split(seps[-1]):
            yield dict(name=name)
    elif isinstance(meta_list[0], basestring): 
        for name in meta_list:
            yield dict(name=name)
    else:
        for named in extract_listed_named(meta_list, force):
            yield named

