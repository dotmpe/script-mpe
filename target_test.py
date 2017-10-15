from __future__ import print_function
import lib
from target import Name, Target, TargetResolver


class Core(TargetResolver):

    namespace = 'rsr', 'http://name.wtwta.nl/#/rsr'

    handlers = [
            'rsr:static',
        ]

    depends = {
            'rsr:static': [],
            'rsr:static2': ['rsr:static'],
        }
    def rsr_static(self):
        print('rsr:static')

    def rsr_static2(self):
        """
        Runs an extension target.
        """
        print('rsr:static2')
        yield 'rsr:addon'


lib.namespaces.update((Core.namespace,))
Target.register(Core)


class Addon(object):

    """
    Inserts a dependency for an existing target.
    """

    namespace = 'rsr', 'http://name.wtwta.nl/#/rsr'

    handlers = [
            'rsr:addon'
        ]
    depends = {
            'rsr:addon': ['rsr:static'],
        }

    def rsr_addon(self, opts=None):
        print('rsr:addon')

Target.register(Addon)


class App(Core):

    handlers = [
            'rsr:static2',
            'rsr:test2',
        ]
    depends = dict(Core.depends.items() + {
            'rsr:test2': ['rsr:static'],
        }.items())

    def rsr_test2(self):
        print("Test2")

Target.register(App)


if __name__ == '__main__':

    print('-------------- Core')
    Core().main()

    print('--------------- App')
    App().main()
