import zope.interface
from zope.interface import Interface, Attribute, implements


class ITarget(zope.interface.Interface):
    """
    """
    handler = Attribute("The actual handler. This returns a generator. ")

    depends = Attribute("Static dependencies. ")

    fetch = Attribute("")

def test():
    from zope.interface.verify import verifyObject
    verifyObject(ITarget, Target())
