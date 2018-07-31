from __future__ import print_function

from twisted.python.filepath import FilePath
from twisted.protocols.basic import LineOnlyReceiver
from twisted.internet.protocol import Factory
from twisted.internet.defer import Deferred
from twisted.internet.endpoints import UNIXClientEndpoint
from twisted.internet import reactor

from script_mpe import libcmd_docopt
from script_mpe.confparse import Values



class JSOTKServerProtocol(LineOnlyReceiver):

    def lineReceived(self, line):
        ctx = self.factory.ctx

        argv = line.split(' ')
        ctx.opts = libcmd_docopt.get_opts(ctx.usage, argv=argv)

        # XXX: twisted likes to use native CRLF (seems) but print does
        # write(str+LF). This should be okay as long as no chunking happens.
        def write(str):
            if str.endswith('\n'):
                self.sendLine(str.strip('\n\r'))
            elif str.strip('\n\r'):
                #assert False, 'untested: %r' % str
                #self.sendLine(str.strip())
                self.transport.write(str.strip('\n\r'))

        #ctx.out = Values(dict( name=str(self.transport), write=write ))

        self.transport.name = str(self.transport)
        ctx.out = self.transport

        if not ctx.opts.cmds:
            print("No subcmd", line, file=ctx.err)
            self.sendLine("? %s" % line)

        elif ctx.opts.cmds[0] == 'exit':
            reactor.stop()
            if hasattr(self.factory, 'postrun'):
                self.factory.postrun(ctx)

        else:
            func = ctx.opts.cmds[0]
            assert func in self.factory.handlers
            try:
                r = self.factory.handlers[func](ctx, self.factory.document)
                if r:
                    self.sendLine("! %s: %i" % (func, r))
                else:
                    self.sendLine("%s OK" % line)
            except Exception as e:
                self.sendLine("!! %r" % e)

        self.transport.loseConnection()


def serve(ctx, document, usage, handlers):

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
    serverFactory.usage = usage
    serverFactory.handlers = handlers
    serverFactory.document = document
    serverFactory.protocol = JSOTKServerProtocol

    print("Listening on %s" % ( address.path ))

    port = reactor.listenUNIX(address.path, serverFactory)
    reactor.run()
