class AttributeMapWrapper(object):

    """
    Translate attribute names using mapping.
    """

    # Attributes always resolved from local instance
    DEFAULT_EXCLUDE = (
            " __init__ "+
            " __getattribute__ __setattribute__"+
            " _adaptee_ _mapping_ _not_attr_ _ign_unkn_ _strict_ _self_ _known_"+
            " init_mapping map_attribute set_adaptee"
        ).split(' ')

    def __init__(self, adaptee, mapping={}, exclude=DEFAULT_EXCLUDE,
            strict=False, ignore_unknown=False):
        """
        Create new attribute mapper. Mapping is a simple dict type with string
        mapping. Excludes is set to reserved names, excluded from attribute
        map. Setting this incorrectly will break it. By deault every name is
        resolved from the adaptee: unknown, unmapped and mapped attribute
        names. To limit to known (mapped or unmapped) names, set ignore-unknown
        on. To limit to mapped keys, turn on strict.
        """
        super(AttributeMapWrapper, self).__init__()
        self._adaptee_ = adaptee
        self._not_attr_= exclude
        self._ign_unkn_= ignore_unknown
        self._strict_ = strict
        if mapping:
            self.init_mapping(mapping)

    def init_mapping(self, mapping):
        self._mapping_ = mapping
        self._self_ = mapping.keys()
        self._known_ = self._self_ + mapping.values()

    def set_adaptee(self, adaptee):
        self._adaptee_ = adaptee

    def map_attribute(self, name):
        """Return translated attribute name or name to resolve on adaptee.
        If none is returned, ignore mapper and resolve on adapter instance.
        """
        if self._strict_:
            if name not in self._self_: return None

        if self._ign_unkn_:
            if name not in self._known_ : return None

        if name in self._mapping_:
            name = self._mapping_[name]
        return name

    def __getattribute__(self, name):
        exclude = object.__getattribute__(self, '_not_attr_')
        if name not in exclude:
            name_ = object.__getattribute__(self, 'map_attribute')(name)
            if name_:
                adaptee = object.__getattribute__(self, '_adaptee_')
                return getattr(adaptee, name_)
        return object.__getattribute__(self, name)

    def __setattribute__(self, name, value):
        exclude = object.__getattribute__(self, '_not_attr_')
        if name not in exclude:
            name_ = object.__getattribute__(self, 'map_attribute')(name)
            if name_:
                adaptee = object.__setattribute__(self, '_adaptee_')
                return setattr(adaptee, name_, value)
        return object.__setattribute__(self, name, value)


if __name__ == '__main__':
    import optparse
    v = optparse.Values(dict(foo='123'))

    a = AttributeMapWrapper(v, dict(
            bar='foo'
        ), ignore_unknown=True)

    print('1', v.foo, a.bar)
    print('2', v.foo, a.foo)
