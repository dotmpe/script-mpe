
class Resourcer(object):
    pass

class Module:
    def configure(self, binder):
        binder.bind(ICommand, to=Resourcer)

class Command(object):
    def run(self, argv):
        injector = Injector(Module())
        injector.get_instance(Resources)

from snakeguice.modules import ConfigModule
from snakeguice.interfaces import Config

from snakeguice import inject, Injected, Config

class MyLogger(object):

    @inject(filename=Config('app.cfg:logger:filename'),
            loglevel=Config('app.cfg:logger:loglevel'))
    def __init__(self, filename,loglevel):
        pass


from myapp import MyConfigAdapter

class MyConfigModule(ConfigModule):

    paths = ['/path/to/config/dir']

    def configure(self, binder):
        binder.bind(Config, to=MyConfigAdapter)


