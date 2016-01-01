"""
Twisted provides for a quick and easy UNIX domain server
for projectdir-meta.
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
from script_mpe.confparse import Values, yaml_load, yaml_safe_dump

from pprint import pformat


class QueryProtocol(LineOnlyReceiver):

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
        elif line == ("! %s" % self.cmd):
            self.factory.ctx.rs = 3
        elif line == ("!! %s" % self.cmd):
            print >>err, "Exception running command:", self.cmd
            self.factory.ctx.rs = 1
        else:
            print line

    def connectionLost(self, reason):
        self.whenDisconnected.callback(None)



def query(ctx):

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
    def lineReceived(self, line):
        #print "Query received", line

        ctx = self.factory.ctx
        argv = line.split(' ')
        ctx.opts = util.get_opts(ctx.usage, argv=argv)
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
        else:
            func = ctx.opts.cmds[0]
            assert func in self.factory.handlers
            try:
                r = self.factory.handlers[func](self.factory.pdhdata, ctx)
                if r:
                    self.sendLine("! %s" % line)
                else:
                    self.sendLine("%s OK" % line)
            except Exception, e:
                self.sendLine("!! %s" % e)

        self.transport.loseConnection()


def serve(ctx, handlers):
    address = FilePath(ctx.opts.flags.address)

    if address.exists():
        raise SystemExit("Cannot listen on an existing path")

    #startLogging(sys.stdout)

    serverFactory = Factory()
    serverFactory.ctx = ctx
    serverFactory.handlers = handlers
    serverFactory.protocol = ServerProtocol
    serverFactory.pdhdata = yaml_load(open(ctx.opts.flags.file))

    port = reactor.listenUNIX(address.path, serverFactory)
    reactor.run()


