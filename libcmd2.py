
commands_namespace = {}


class CommandRegistry(object):

    # Static context
    default_ns = 'default'

    @staticmethod
    def get_instance(namespace=None, initialize=False):
        if not namespace:
            namespace = CommandRegistry.default_ns
        if namespace in commands_namespace:
            assert not initialize
            return commands_namespace[namespace]
        elif initialize:
            assert namespace not in commands_namespace
            instance = CommandRegistry(namespace=namespace)
            commands_namespace[instance.namespace] = instance
            return instance
        else:
            raise Exception("No such command namespace: %r" % self.namespace)

    # Instance context
    namespace = None
    handlers = None

    def __init__(self, namespace):
        super(CommandRegistry, self).__init__()
        self.namespace = namespace
        self.handlers = {}

    def __call__(self, func):
        assert callable(func), (self, func)
        sid = func.__name__
        assert sid not in self.handlers, sid
        self.handlers[sid] = func
        return self

    def __getattr__(self, name):
        if name in self.handlers:
            return self.handlers[name]
        else:
            return super(CommandRegistry, self).__getattr__(name)

    def run(self, name):
        context = {}
        self.handlers[name](context)

    #@classmethod
    def register(self, **params):
        #print self, params
        return self

    @classmethod
    def main(klass):
        reg = CommandRegistry.get_instance()
        reg.run('status')

    def __repr__(self):
        return "<CommandRegistry %s %r>" % (id(self), self.handlers)



def register(func):
    initialize = False
    if CommandRegistry.default_ns not in commands_namespace:
        initialize = True
    reg = CommandRegistry.get_instance(initialize=initialize)
    return getattr(reg(func), func.__name__)



class Command:

    ns = 'cmd'

    #@CommandHandler.register(arg='more args')
    @register#('test')
    def status(context):
        print 'status', context

    @register
    def verify(self):
        pass

    @register
    def build(self):
        pass

    @register
    def report(self):
        pass


class CommandSet2:

    ns = 'rsr'

    @register(depends='')
    def ident_user(context):
        pass

    @register(depends='ident-host ident-user')
    def ident(context):
        pass

    @register(depends='ident')
    def update(context):
        print context.ns, context.name, context


CommandRegistry.main()

