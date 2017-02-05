"""
Background script server in Python, Twisted.

API:
    - serve( context, subcmds, prerun=None, postrun=None )
    - query( context )

- Subcommands is a simple name, function mapping.
  Prerun/postrun are executed before and after.
  The arguments passed to the subcmd handlers are simple too,
  parsing done using docopt.

  The prerun argument may return arguments to prepend to the subcmd handler.
  Normally the following are passed:

    1. prerun(context, cmdline)
    2. context

- Context schema:
    'usage'
        - docopt specification.
    'opts'
        'flags'
            'file'
                - Path to document file.
            'address'
                - Path to unix domain socket.
        'cmds'
            - List of commands to execute (normally only one).
    'out'
        - Output stream relayed to client.
    'err'
        - Stderr stream.
    'rs'
        - Use to pass exit code back from client to query method.

"""
import os, sys

#from twisted.python.log import startLogging
from twisted.python.filepath import FilePath
from twisted.protocols.basic import LineOnlyReceiver
from twisted.internet.protocol import Factory
from twisted.internet.defer import Deferred
from twisted.internet.endpoints import UNIXClientEndpoint
from twisted.internet import reactor

from script_mpe import util
from script_mpe.confparse import Values



class QueryProtocol(LineOnlyReceiver):

    """
    A simple python UNIX domain socket client, to
    execute subcommands at the server process.
    """

    def __init__(self):
        self.whenDisconnected = Deferred()

    def connectionMade(self):
        self.cmd = self.factory.cmd
        self.sendLine(self.cmd)

    def lineReceived(self, line):
        line = line.strip('\n\r')
        err = self.factory.ctx.err
        if line == ("%s OK" % self.cmd):
            self.transport.loseConnection()

        elif line == ("? %s" % self.cmd):
            print >>err, "Command not recognized:", self.cmd
            self.factory.ctx.rs = 2

        elif line.startswith('! '):
            self.factory.ctx.rs = int(line.split(' ')[2])

        elif line.startswith('!! '):
            print >>err, "Exception running command:", self.cmd
            self.factory.ctx.rs = 1

        else:
            print line

    def connectionLost(self, reason):
        self.whenDisconnected.callback(None)



def query(ctx):

    """"
    Execute subcommand through UNIX domain socket client.
    """

    if not ctx.opts.argv:
        print >>ctx.err, "No command %s" % ctx.opts.argv[0]
        return 1

    address = FilePath(ctx.opts.flags.address)

    factory = Factory()
    factory.ctx = ctx
    ctx.rs = 0

    factory.protocol = QueryProtocol
    factory.quiet = True
    factory.cmd = ' '.join(ctx.opts.argv)

    endpoint = UNIXClientEndpoint(reactor, address.path)
    connected = endpoint.connect(factory)

    def succeeded(client):
        return client.whenDisconnected
    def failed(reason):
        print >>ctx.err, "Could not connect:", reason.getErrorMessage()
    def disconnected(ignored):
        reactor.stop()

    connected.addCallbacks(succeeded, failed)
    connected.addCallback(disconnected)

    reactor.run()

    return factory.ctx.rs


class ServerProtocol(LineOnlyReceiver):

    """
    Line-based receiver expects to decodes input to context using
    the prerun callback. The handlers should use ctx.out etc. to interact
    back with the client.
    """

    def lineReceived(self, line):
        ctx = self.factory.ctx

        preload = self.factory.prerun(ctx, line)

        # XXX: twisted likes to use native CRLF (seems) but print does
        # write(str+LF). This should be okay as long as no chunking happens.
        def write(str):
            if str.endswith('\n'):
                self.sendLine(str.strip('\n\r'))
            elif str.strip('\n\r'):
                #assert False, 'untested: %r' % str
                #self.sendLine(str.strip())
                self.transport.write(str.strip('\n\r'))

        ctx.out = Values(dict( write=write ))

        if not ctx.opts.cmds:
            print >>ctx.err, "No subcmd", line
            self.sendLine("? %s" % line)

        elif ctx.opts.cmds[0] == 'exit':
            reactor.stop()
            self.factory.postrun(ctx)

        else:
            func = ctx.opts.cmds[0]
            assert func in self.factory.handlers
            args = tuple( preload ) + ( ctx, )
            try:
                r = self.factory.handlers[func](*args)
                if r:
                    self.sendLine("! %s: %i" % (func, r))
                else:
                    self.sendLine("%s OK" % line)
            except Exception, e:
                self.sendLine("!! %r" % e)

        self.transport.loseConnection()


def prerun(ctx, cmdline):

    """
    Process context before subcommand invocation.
    This function is part of the ``serve()`` signature
    to allow a customized prerun.
    """

    argv = cmdline.split(' ')
    ctx.opts = util.get_opts(ctx.usage, argv=argv)

def postrun(ctx):

    """
    Cleanup after reactor has passed.
    This function is part of the ``serve()`` signature
    to allow a customized postrun.
    """
    pass


def serve(ctx, handlers, prerun=prerun, postrun=postrun):

    """
    Start protocol at socket address path. Handlers is a dict
    of sub-command names, and corresponding functions.
    See above for the two callbacks prerun and postrun.
    """

    address = FilePath(ctx.opts.flags.address)

    if address.exists():
        raise SystemExit("Cannot listen on an existing path")

    #startLogging(sys.stdout)

    serverFactory = Factory()
    serverFactory.ctx = ctx
    serverFactory.handlers = handlers
    serverFactory.prerun = prerun
    serverFactory.postrun = postrun
    serverFactory.protocol = ServerProtocol

    port = reactor.listenUNIX(address.path, serverFactory)
    reactor.run()



