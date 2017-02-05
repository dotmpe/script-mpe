"""
"""
import types

import ruamel.yaml as yaml

import lib


yaml_load = yaml.load
yaml_dump = yaml.dump


class Base(object):

#    def __init__(self, name, super_):
#        self._name = name
#        self._super = super_

    @property
    def root(self):
        mod = self
        while hasattr(mod, '_super') and mod._super:
            mod = mod._super
        return mod

    @property
    def path(self):
        path = []
        mod = self
        while mod:
            path.insert(0, mod._name)
            if hasattr(mod, '_super') and mod._super:
                mod = mod._super
            else:
                break
        return ":" + ".".join(path)

    def __repr__(self):
        return self.path


class Object(Base):

    def _save_yaml(): pass

    def __getitem__(self, item):
        return getattr(self, "_%i" % item)

#    def __setattr__(self, name, value):
#        print self.path, '__setattr__', name, value
#        return super(Object, self).__setattr__(name, value)

#    def __setattribute__(self, name, value):
#        seqs = tuple, list, set, frozenset
#        if isinstance(value, dict):
#            self.__dict__[name] = obj_dic(value, name=name, super_=self)
##            setattr(self, name, obj_dic(value, name=name, super_=self))
#        elif isinstance(value, seqs):
#            self.__dict__[name] = obj_lis(value, name=name, super_=self)
##            setattr(self, name, obj_lis(value, name=name, super_=self))
#        else:
#            self.__dict__[name] = PropertyValue(name, value, self)
##            setattr(self, name, PropertyValue(name, value, self))

    def copy(self):
        keys = [k for k in self.__dict__.keys() if not k.startswith('_')]
        items = [ (k,getattr(self, k)) for k in keys ]
        return dict([
            ( k, v.copy() ) if hasattr(v, 'copy') else ( k, v )
            for k, v in items ])


class PropertyValue(Base):
    def __init__(self, k, v, super_):
        self.value = v
        self._super = super_
        self._name = k
        super(PropertyValue, self).__init__()#k, super_)

    def __getattr__(self, obj, objtype=None):
        print '<getattr', self, obj, objtype, '>'

    def __get__(self, obj, objtype=None):
#        print '<get', self, obj, objtype, '>'
        return self.value

    def __set__(self, obj, value):
#        print '<set', self, obj, objtype, '>'
        assert isinstance(value, type(self.value))
        self.value = value

    def __str__(self):
# XXX
        return 'PropertyValue:'+str(self.value)

    def __delete__(self, obj):
        pass

    def copy(self):
        return self.value


def _li(self, item, value=None):
    return getattr(self, "_%i" % item)


def obj_lis(l, name='obj_lis', super_=None):
    class_ = type(name, (Object,), {'_name':name, '_super': super_})#d)
    seqs = tuple, list, set, frozenset
    for i, j in enumerate(l):
        k = '_%i' % i
        if isinstance(j, dict):
            setattr(class_, k, obj_dic(j, name=k, super_=class_))
        elif isinstance(j, seqs):
            setattr(class_, k, obj_lis(j, name=k, super_=class_))
        else:
            setattr(class_, k, PropertyValue(k, j, class_))
    return class_()
    top = class_()#name, super_)
    return top

def obj_dic(d, name='obj_dic', super_=None):
    class_ = type(name, (Object,), {'_name':name, '_super': super_})#d)
    seqs = tuple, list, set, frozenset
    for i, j in d.items():
        if isinstance(j, dict):
            setattr(class_, i, obj_dic(j, name=i, super_=class_))
        elif isinstance(j, seqs):
            setattr(class_, i, obj_lis(j, name=i, super_=class_))
        else:
            setattr(class_, i, PropertyValue(i, j, class_))
            a = getattr(class_, i)
    return class_()
    top = class_()#name, super_)
    return top


#o = obj_dic({'test':'foo'})


