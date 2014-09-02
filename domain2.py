#!/usr/bin/env python
"""domain2 - scrape interface reports

Establish host ID, and track network interfaces, hostnames and last IP address.

There is a settings schema established to record the data on-disk. 

TODO: should record network domain names, use this with ifaces.
FQDN are not used really, except to put the last known network/IP.
"""
__usage__ = """
Usage:
  domain.py [options] info
  domain.py ipforhost <host>
  domain.py net ([info]|set <name>)
  domain.py detect
  domain.py help
  domain.py -h|--help
  domain.py --version

Options:

Other flags:
    -c RC --config=RC
                  Use config file to load settings [default: ~/.domain.rc]
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: ~/.domain.sqlite].
    -h --help     Show this screen.
    --version     Show version.
    -i --interactive
                  Enable interactive mode, for getting input or resolving
                  choices.

"""
__settings__ = """
interfaces
    A registry for all known network interfaces (WIFI and Ethernet types)
domain
    A hierarchy of local domains. The value contains the current or last known
    IP and an up/down report. The hostname should be retrievable from nodes.
nodes
    A registry for all known nodes. Networked boxes list their interfaces,
    and hostname aliases.
"""

from datetime import datetime
import os
import re
from pprint import pformat
import hashlib
import uuid
import socket

from docopt import docopt

from rsrlib.plug.net import get_hostname, get_gateway, get_default_route
#def get_hostname():
#    return socket.gethostname().split('.').pop(0)

import log
import util
import res
import domain

from taxus.init import SqlBase, get_session
from taxus.net import Host



models = [ Host ]


__version__ = '0.0.0'
hostIdFile = os.path.expanduser('~/.cllct/host.id')

def get_current_host(settings):
    """
    Scan settings.nodes for UNID and return host.
    """
    unid, name = res.read_idfile(hostIdFile)
    # XXX to use an UNID, or SID.. Rather have ser. nrs anyway.
    for sid, host in settings.nodes.items():
        if 'unid' in host and host['unid'] == unid:
            return host

def get_domain(settings, host, init=False):
    """
    Get/set given host from settings.domain tree.
    """
    # resolve domain top-down on Values object
    dparts = host.split('.')
    d = settings.networks
    while dparts:
        p = dparts.pop()
        d = d.get(p, init)
    return d

def get_network(settings, net, init=False):
    """
    Get/set given net from settings.domain tree.
    """
    # resolve domain top-down on Values object
    dparts = net.split('.')
    n = settings.networks
    while dparts:
        p = dparts.pop(0)
        print p, n
        n = n[p]
        #XXX n = n.get(p, init)
    return n

def init_host(settings):
    """
    Reinitialize or initialize host instance from environment and stored settings.
    """
    host = dict( name = get_hostname() )
    hostnameId = host['name'].lower()
    if hostnameId not in settings.nodes:
        ifaces = {}
        for iface, mac, spec in domain.inet_ifaces():
            if mac in settings.interfaces:
                raise Exception("Found existing interface", mac)
            else:
                settings.interfaces[mac] = ifaces[mac] = dict(
                    node = hostnameId
                )
        if settings.interactive:
            name = Prompt.raw_input("Give a name for this node", host['name'])
        host.update(dict(
            unid = str(uuid.uuid4()),
            interfaces = ifaces.keys()
        ))
        settings.nodes[hostnameId] = host
        open(hostIdFile, 'w+').write(" ".join((host['unid'], host['name'])))
        log.std("{bwhite}Wrote new host, {green}%s {default}<{bblack}%s{default}>",
            host['name'], host['unid'])
        settings.commit()
    else:
        host = get_current_host(settings)
        log.std("{bwhite}Found host, {green}%s {default}<{bblack}%s{default}>",
            host['name'], host['unid'])
    #return host

def init_domain(settings):
    """
    Use SSH key to determine current domain.
    The public file should have a user@domain in the comment part.
    """
    keyFile = os.path.expanduser('~/.ssh/id_rsa.pub')
    if not os.path.exists(keyFile):
        keyFile = os.path.expanduser('~/.ssh/id_dsa.pub')
    if not os.path.exists(keyFile):
        raise Exception("No SSH keyfile")
    pubkeylines = res.read_unix(keyFile)
    assert len(pubkeylines) == 1, pubkeylines
    keytype, key, localId = pubkeylines.pop().split(' ')
    user, domain = localId.split('@')
    # init settings.domain tree
    d = get_domain(settings, domain, True)
    return user, d

def cmd_info(domain, settings):

    """
    Print IP's for interfaces on domain.
    Initialize current host, creating host ID if not present yet and record
    hosts interfaces.
    Then determine the current domain, and record current iface IP's.
    Commit data if needed.
    """

    # read host ID file or record node/ifaces
    host = init_host(settings)

    # read SSH pubkey user domain
    user, domain = init_domain(settings)

    print domain.path()

    updated = False
    for iface, mac, spec in inet_ifaces():
        ip = spec['inet']['ip']
        iface_type = settings.interfaces[mac].type
        if iface not in domain:
            domain.get(iface_type, dict(ip=None))
        if domain[iface_type].ip != ip:
            domain[iface_type].ip = ip
            updated = True
        print '\t', iface, ip
    if updated:
        settings.commit()

def cmd_ipforhost(host, settings):
    """
    XXX Given hostname, want IP for local connected interfaces.
        But there is no network topology yet?
    """
    if host:
        d = get_domain(host, settings)
        print d.path()
        for iface, spec in d.copy(True).items():
            print '\t', iface, spec['ip']

def cmd_net_info(name, settings):
    sa = get_session(settings.dbref)
    print name
    for host in sa.query(Host).all():
        print host

def cmd_net_set(name, settings):
    """
    """
    h = socket.gethostname()
    print h
    d = get_domain(settings, h)
    print d, d.keys()
    n = get_network(settings, 'net.wylnd.tp-1')
    print n, n.keys(), n.links.wifi, n.links.ethernet
    print get_current_host(settings)
    print get_default_route()

def cmd_detect(settings):
    """
    Set host net domain name.
    Detect network using link
    Get full current hostname using gateway,
    update current domain and IP.
    """
    gateway, mac, gateway_addr = get_gateway(settings)
    host = get_current_host(settings)
    for iface in host.interfaces:
        iface_type = settings.interfaces[iface].type
        net = gateway.suffix[iface_type]
        s = net.split('.')
        s.reverse()
        domain = '.'.join(s)
        s.insert(0, host.name.lower())
        domainhost = '.'.join(s)
        d = get_domain(settings, domain, True)
        # print host, IP
        print d.nodes[host.name.lower()], domainhost, host.name.lower()


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    #config = confparse.expand_config_path('domain.rc')
    opts.flags.configPath = os.path.expanduser(opts.flags.config)
    settings = util.init_config(opts.flags.configPath, dict(
            nodes = {}, interfaces = {}, domain = {}
        ), opts.flags)

    opts.default = 'info'

    # FIXME: share default dbref uri and path, also with other modules
    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'domain.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__doc__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))

