"""
Collection of interfaces.

Another reiteration of a previous unfinished implementation in taxus_out.
"""
import zope.interface
from zope.interface import Interface, Attribute, implements


class ISimpleCommand(zope.interface.Interface):
    """
    """

class IName(zope.interface.Interface):
    """
    """

class ITarget(IName):
    """
    A static reference to a global target handler implementation
    registered to some code block.
    """
    handler = Attribute("The actual handler. This returns a generator. ")
    depends = Attribute("Static dependencies, a list of ITarget. ")

class ICommand(zope.interface.Interface):
    """
    A reference to an ITarget that keeps pre- and post execution state
    variables.
    """
    prerequisites = Attribute("Static dependencies, a list of ICommand "
            "TODO: or IResource")
    requirements = Attribute("Dynamic targets, a list of ICommand. "
            "TODO: or IResource")
    results = Attribute("Results: targets and resources, a list of ICommand or "
            "IResource. ")

    fetch = Attribute("")

class IReportable(zope.interface.Interface):
    """
    Interface for reportable objects, adaptable to report instances.
    To use with libcmd and reporer.Reporter class.
    """

class IReport(zope.interface.Interface):
    """
    Interface for report instances.
    To use with libcmd and reporer.Reporter class.
    """
    text = Attribute("A text fragment (readonly). ")
    ansi = Attribute("An ANSI formatted variant of `text` (readonly).")
    level = Attribute("A level associated with the text fragment (readonly). ")

    formatting = Attribute("Preformatted, monospace text is 'static', or 'normal' for flowed. ")
    line_width = Attribute("If needed, indicate minimal line-width. ")
    line_width_preferred = Attribute("Optionally, indicate preferred line-width. ")


def test():
    from zope.interface.verify import verifyObject
    verifyObject(ITarget, Target())


