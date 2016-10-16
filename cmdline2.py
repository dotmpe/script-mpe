from .libname import Namespace, Name
from .libcmdng import Targets, Arguments, Keywords, Options,\
    Target, TargetResolver


NS = Namespace.register(
        prefix='cmd',
        uriref='http://project.dotmpe.com/script/#/cmdline2'
    )

Options.register(NS)

@Target.register(NS, 'options')
def cmd_options(prog=None, opts=None):
    pass


if __name__ == '__main__':
    # libcmdng
    TargetResolver().main(['cmd:options'])




