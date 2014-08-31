#!/usr/bin/env python
"""domain2 - scrape interface reports

Establish host ID, and track network interfaces, hostnames and last IP address.

There is a settings schema established to record the data on-disk. 
FQDN are not used really, except to put the last known network/IP.
"""
__usage__ = """
Usage:
  domain.py [options] info
  domain.py help
  domain.py -h|--help
  domain.py --version

Options:

Other flags:
    -c RC --config=RC
                  Use config file to load settings [default: ~/.domain.rc]
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

from docopt import docopt
import zope.interface
import zope.component

from rsrlib.plug.net import get_hostname, get_gateway

import log
import util
import res
import domain



__version__ = '0.0.0'
hostIdFile = os.path.expanduser('~/.cllct/host.id')

def get_current_host(settings):
    """
    Scan persisted node list for UNID.
    """
    unid, name = res.read_idfile(hostIdFile)
    for sid, host in settings.nodes.items():
        if 'unid' in host and host['unid'] == unid:
            return host

def inet_ifaces():
    """
    Return network interfaces with inet specs.
    """
    for iface, spec in domain.parse_ifconfig():
        if 'inet' in spec:
            mac = spec['mac']
            yield iface, mac, spec

def init_host(settings):
    """
    Reinitialize or initialize host instance from environment and stored settings.
    """
    host = dict( name = get_hostname() )
    hostnameId = host['name'].lower()
    if hostnameId not in settings.nodes:
        ifaces = {}
        for iface, mac, spec in inet_ifaces():
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
    dparts = domain.split('.')
    d = settings.domain
    while dparts:
        p = dparts.pop()
        d = d.get(p)
    return user, d

def cmd_info(settings):

    """
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
        if iface not in domain:
            domain.get(iface, dict(ip=None))
        if domain[iface].ip != ip:
            domain[iface].ip = ip
            updated = True
        print '\t', iface, ip
    if updated:
        settings.commit()



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

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'domain.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__doc__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))

