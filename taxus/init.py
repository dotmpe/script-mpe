from pprint import pformat

from sqlalchemy.sql import sqltypes
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import create_engine, event, Column, ForeignKey
from sqlalchemy.orm import sessionmaker
from sqlalchemy.engine import Engine

import zope.interface

from script_mpe import log
from script_mpe.confparse import yaml_load, Values
from . import iface
from . import out

from script_mpe import res
from script_mpe.res.d import get_default, default


# class-registry maps model name to type.
# Also accesible with Model._decl_class_registry
class_registry = {}
SqlBase = declarative_base(class_registry=class_registry)


def register_sqlite_connection_event():
    @event.listens_for(Engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        """
        On connect, assume is SQLite and > 3.6.19
        """
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


def get_session(dbref, initialize=False, metadata=SqlBase.metadata):
    if dbref.startswith('sqlite'):
        register_sqlite_connection_event()
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



### metadata to SA model unmarshalling

def extract_schema(gen_meta_ctx):
    """
        TODO Simplify models subtree to JSON schema..
    """
    #assert gen_meta_ctx['schema']['version']  ==  0.1

def extract_orm(gen_meta_ctx, sql_base=None):

    """
    Run over all models. TODO Extract metadata to construct SA ORM types.
    """

    #assert gen_meta_ctx['schema']['version']  ==  0.1
    if not sql_base:
        sql_base = declarative_base()
        sql_base.registry = {}
        yield sql_base
    else:
        assert sql_base.registry
    models = list(extract_listed_named(gen_meta_ctx['schema']['models']))
    for model_meta in models:
        model = extract_model(model_meta, sql_base=sql_base)
        sql_base.registry[model.name] = model
    while models:
        model_meta = models.pop(0)
        model = extract_model(model_meta, sql_base=sql_base)
        if model.mixins:
            model_mixins = list(extract_listed_names(model.mixins))
            for named in model_mixins:
                assert named['name'] in sql_base.registry, (
                        "No mixin named %s" % named, list(sql_base.registry.keys()))
                mixin = sql_base.registry[named['name']].copy(True)
                for k in ("name", "type"):
                    del mixin[k]
                res.d.deep_update(model, mixin)
        model_extends = default('extends', model_meta)
        if model_extends:
            if model_extends not in sql_base._decl_class_registry:
                models.append(model)
                continue
            extends = (sql_base._decl_class_registry[model_extends],)
        else:
            extends = (sql_base,)
        type_dict = dict(
                __tablename__ = model.table
            )
        if model.type in ('Mixin',):
            pass
        else:
            indices = extract_indices(model)
            assert indices.primary, indices.copy(True)
            relations = extract_relations(model)
            for field in extract_listed_named(model.fields):
                type_dict[field['name']] = extract_field(
                        model, indices, relations, field)
            yield type(model_meta['name'], extends, type_dict)

            assert model.name in sql_base._decl_class_registry, (model.name,
                    list(sql_base._decl_class_registry.keys()))


def extract_model(model_meta, sql_base):
    model_type = default('type', model_meta)
    model_extends = default('extends', model_meta)
    model_table = default('table', model_meta)
    model_name = default('name', model_meta)
    model_mixins = default('mixins', model_meta, [])
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
            assert not indices.primary, (index, indices.primary)
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

def extract_relations(model_meta):
    default('relations', model_meta, [])
    defs = {}
    relations = {'defs': defs, 'to': {}, 'from': {}}
    named_relations = extract_listed_named(model_meta.relations, force=False)
    for relation in named_relations:
        if relation.type == 'one-to-one':
            pass
        else:
            assert False, relation.type
        model_to, field_to = relation['to'].rsplit('.', 1)
        model_from, field_from = relation['from'].rsplit('.', 1)
        default('name', relation, relation['from']+'_'+relation['to'])
        relations['defs'][relation.name] = relation.copy(True)
        for k, field, model in (('to', field_to, model_to), ('from', field_from, model_from)):
            if model not in relations[k]:
                relations[k][model] = {}
            if field in relations[k][model]:
                assert relations[model][field] == relation.name, \
                    (relations[k][model][field], relation.name)
            else:
                relations[k][model][field] = relation.name
    return relations

def extract_field(model, indices, relations, field_meta):
    field_type = default('type', field_meta, 'String')
    field_extends = default('extends', field_meta)
    field_name = default('name', field_meta)
    field_len = get_default('len', field_meta)
    db_field = get_default('db_name', field_meta, field_name)
    assert field_type, field_name
    if field_type == 'relate':
        return Values(field_meta)
    else:
        col_type = getattr(sqltypes, field_type)
        kwds = {}
        args = []
        if indices.primary == field_name or field_name in indices.primary:
            kwds['primary_key'] = True
        elif field_name in indices.unique:
            kwds['unique'] = True
        elif field_name in indices.normal:
            kwds['index'] = True
        # XXX if model.name in relations['from'] and field_name in relations['from'][model.name]:
        if model.table in relations['from'] and db_field in relations['from'][model.table]:
            relname = relations['from'][model.table][db_field]
            target = relations['defs'][relname]['to']
            #model, field = target.rsplit('.', 1)
            args.append(ForeignKey(target))
        if field_len:
            try:
                col_type = col_type(field_len)
            except:
                raise Exception("%s does not accept length" % col_type)
        #print 'Column', model.name, field_name, db_field, col_type, args, kwds
        return Column(db_field, col_type, *args, **kwds)


def extract_listed_named(meta_list, force=True):
    """
    Accept either dict or list, generate dicts that are assured to have a name
    property. In case of passing a dict in this name is copied over from
    meta_list if needed, or forced to be equal to the key.
    In case meta_list is an actual list already, name should be given.
    """
    isList = isinstance( meta_list, list )
    if isList:
        pass#k = list(pluck('name', meta_list))
    else:
        k = list(meta_list.keys())
        #k.reverse() # XXX test, dict traverse reverse source-order
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
    if isinstance(meta_list, str):
        raw = meta_list
        seps = list(sep)
        while seps[:-1]:
            raw = raw.replace(seps.pop(0), seps[-1])
        for name in raw.split(seps[-1]):
            yield dict(name=name)
    elif isinstance(meta_list, list) and len(meta_list) > 2 and isinstance(meta_list[2], str):
        for name in meta_list:
            yield dict(name=name)
    else:
        for named in extract_listed_named(meta_list, force):
            yield named
