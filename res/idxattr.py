"""
NOTE: experimenting with zope.interfaces, components. move out of res. prolly?
"""
class IndexAttributeWrapper(object):

    """
    Access values on indexed objects as attribues.
    """

    # Attributes always resolved from local instance
    DEFAULT_EXCLUDE = (
            " __init__ "+
            " __getattribute__ __setattribute__"+
            " _adaptee_ _not_attr_ _fields_"+
            " idx_attribute set_adaptee"
        ).split(' ')

    def __init__(self, adaptee, fields=[], exclude=DEFAULT_EXCLUDE):
        """
        Translate attribute names to index in list.
        """
        super(IndexAttributeWrapper, self).__init__()
        self._adaptee_ = adaptee
        self._not_attr_= exclude
        self._fields_ = fields

    def set_adaptee(self, adaptee):
        self._adaptee_ = adaptee

    def idx_attribute(self, name):
        if name in self._fields_:
            return self._fields_.index(name)

    def __getattribute__(self, name):
        exclude = object.__getattribute__(self, '_not_attr_')
        if name not in exclude:
            i = object.__getattribute__(self, 'idx_attribute')(name)
            if isinstance(i, int):
                adaptee = object.__getattribute__(self, '_adaptee_')
                return adaptee[i]
        return object.__getattribute__(self, name)

    def __setattribute__(self, name, value):
        exclude = object.__getattribute__(self, '_not_attr_')
        if name not in exclude:
            i = object.__getattribute__(self, 'idx_attribute')(name)
            if isinstance(i, int):
                adaptee = object.__setattribute__(self, '_adaptee_')
                adaptee[i] = value
        object.__setattribute__(self, name, value)


if __name__ == '__main__':
    d = [1,'a',True]
    f = "num char bool".split(" ")
    i = IndexAttributeWrapper(d, f)
    print(i.num)
    print(i.char)
    print(i.bool)
