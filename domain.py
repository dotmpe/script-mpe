#!/usr/bin/python
import os
import re
import socket
import sys

import yaml

import confparse


config = confparse.get_config('cllct.rc')
"Root configuration file."

settings = confparse.yaml(*config)
"Static, persisted settings."

def err(msg, *args):
    print >>sys.stderr, msg % args

def hex_mask_to_dotquad(h):
    if h.startswith('0x'):
        h = h[2:]
    return "%i.%i.%i.%i" % (
            int(h[0:2],16),
            int(h[2:4],16),
            int(h[4:6],16),
            int(h[6:8],16))


def parse_ifconfig_linux(data):
    ifcblock = ''
    ifname = ''
    ifs = ()
    ifconfig = {}
    for d in data:
        if d.strip() and not d.startswith(' '):
            if ifcblock:
                macaddr = re.search(r'HWaddr\ ([0-9a-f:]+)\ ', ifcblock).group(1)
                ifconfig['mac'] = macaddr
                inet = re.search(r'inet\ addr:[^\ ]+\ +Bcast:[^\ ]+\ +Mask:[^\ ]+', ifcblock)
                if inet:
                    ipaddr = re.search(r'inet\ addr:([0-9]{1,3}(\.[0-9]{1,3}){3})\ ', ifcblock).group(1)
                    netmask = re.search(r'inet\ addr:[^\ ]+\ +Bcast:([0-9]{1,3}(\.[0-9]{1,3}){3})\ ', ifcblock).group(1)
                    bcast = re.search(r'inet\ addr:[^\ ]+\ +Bcast:[^\ ]+\ +Mask:([0-9]{1,3}(\.[0-9]{1,3}){3})\ ', ifcblock).group(1)
                    ifconfig['inet'] = {
                            'ip': ipaddr,
                            'broadcast': bcast,
                            'netmask': netmask,
                        }
            p = d.find(' ')
            ifname = d[:p].strip()
            ifs += ((ifname, ifconfig),)
            ifconfig = {}
            ifcblock = d[p:].strip()
        else:
            ifcblock += ' ' + d.strip()
    return ifs

def parse_ifconfig_bsd(data):
    ifcblock = ''
    ifname = ''
    ifs = ()
    ifconfig = {}
    for d in data:
        if d.strip() and not d[0].isspace():
            if ifcblock:
                macaddr = re.search(r'ether\ ([0-9a-f:]+)\ ', ifcblock)
                if macaddr:
                    ifconfig['mac'] = macaddr.group(1)
                inet = re.search(r'inet\ [0-9\.]+\ netmask\ 0x[0-9a-f]+\ broadcast\ [0-9\.]+', ifcblock)
                if inet:
                    ipaddr = re.search(r'inet\ ([0-9]{1,3}(\.[0-9]{1,3}){3})\ ', ifcblock).group(1)
                    netmask_hex = re.search(r'inet\ [0-9\.]+\ netmask\ 0x([0-9a-f]+)\ broadcast\ [0-9\.]+', ifcblock).group(1)
                    bcast = re.search(r'inet\ [0-9\.]+\ netmask\ 0x[0-9a-f]+\ broadcast\ ([0-9\.]+)', ifcblock).group(1)
                    ifconfig['inet'] = {
                            'ip': ipaddr,
                            'broadcast': bcast,
                            'netmask': hex_mask_to_dotquad(netmask_hex),
                        }
            p = d.find(' ')
            ifname = d[:p].strip().strip(':')
            ifs += ((ifname, ifconfig),)
            ifconfig = {}
            ifcblock = d[p:].strip()
        else:
            ifcblock += ' ' + d.strip()
    return ifs

def parse_ifconfig(ifconfig='/sbin/ifconfig'):
    data = os.popen(ifconfig).readlines()
    if sys.platform == 'darwin':
        return parse_ifconfig_bsd(data)
    elif sys.platform == 'linux2':
        return parse_ifconfig_linux(data)
    else:
        raise Exception

def get_dest_info(addr):
    if sys.platform == 'darwin':
        data = os.popen('/usr/sbin/arp %s' % (addr)).readlines()
    elif sys.platform == 'linux2':
        data = os.popen('/usr/sbin/arp -a %s' % (addr)).readlines()
    if 'no match' in data[0]:
        return
    for d in data:
        m = re.search("([^\ ]+)\ \(([0-9\.]+)\) at ([0-9a-f:]+) ", d)
        if not m: continue
        host, ipaddr, hwaddr = m.groups()
        iface = re.search("on ([a-z][a-z0-9]+)", d).group(1)
        yield iface, ipaddr, host, hwaddr

def get_mac(addr):
    a = get_dest_info(addr)
    try:
        return a.next()[3]
    except StopIteration, e:
        return

def get_default_route():
    if sys.platform == 'darwin':
        data = [l.strip() for l in
                os.popen("netstat -nr | grep '^default' | awk '/default/ {print $2}' ").readlines()]
        return data
    elif sys.platform == 'linux2':
        data = [l.strip() for l in
                os.popen("ip route show default | grep '^default' | awk '/default/ {print $3}' ").readlines()]
        return data
    else:
        raise Exception


def assert_node(host):
    global settings
    if host not in settings.node:
        addr = socket.gethostbyname(host)
        node = {
            'mac': get_mac(addr),
            'ip': addr,
        }
        #setattr(settings.node, host, confparse.Values(node,root=settings.node))
        settings.node[host] = confparse.Values(node,root=settings.node)
        settings.commit()
        settings = settings.reload()

def assert_gateway(node):
    assert 'domain' in node
    assert 'local' in node

def get_hostname():
    host = socket.gethostname().split('.').pop(0)
    getfqdn = socket.getfqdn()
    if getfqdn.split('.').pop(0) != host:
        err("Hostname does not match subdomain: %s (%s)", host, getfqdn)
    assert_node(host)    
    return host

def get_gateway():    
    default_routes = get_default_route()
    if not default_routes:
        return None

    node = None
    gateway_node = None
    for gateway in default_routes:
        m = get_mac(gateway)
        if not m:
            continue
        try:
            gateway_node = socket.gethostbyaddr(gateway)[0]
        except socket.herror, e:
            err(e)
            continue
        if gateway_node and node:
            err("Multiple gateways, keeping first: %s, %s", node, gateway_node)
        else:
            node = gateway_node

    if node:
        assert_node(node)
        assert_gateway(node)

    return node

def info():
    # determine gateway, and identify node by hardware address
    # record new gateways

    # print some stuff
    hostname = get_hostname()
    print "On node:", hostname
    gateway = get_gateway()
    print 'Internet gateway: '
    default_routes = get_default_route()
    for gateway in default_routes:
        print '\t-', gateway, 
        m = get_mac(gateway)
        if not m:
            print '(invalid)'
            continue
        else:
            try:
                gateway_node = socket.gethostbyaddr(gateway)[0]
            except socket.herror, e:
                print '(invalid: %s)' % e
                continue
            print gateway_node, "[ether %s]" % m

    for gateway in default_routes:
        m = get_mac(gateway)
        if m:
            try:
                gateway_node = socket.gethostbyaddr(gateway)[0]
            except socket.herror, e:
                print >>sys.stderr, e
                continue
            if gateway_node not in settings.node:
                print "New gateway: %s" % gateway_node,
                node = {
                        'mac': m,
                        'ip': gateway,
                    }
                print node
                v = raw_input('Insert node? [n] ')
                if 'y' in v:
                    gw_domain = None
                    prompt = 'Domain? '    
                    if '.' in gateway_node:
                        p = gateway_node.find('.')
                        gw_domain = gateway_node[p+1:]
                        if gw_domain in settings.domain:
                            prompt += '[%s] ' % gw_domain
                        else:
                            prompt += '[%s +] ' % gw_domain
                    domain = raw_input(prompt)
                    if not domain and gw_domain:
                        domain = gw_domain
                    if domain not in settings.domain:
                        pass # TODO
                    updated = True
                    node['domain'] = domain
                    setattr(settings.node, gateway_node, node)
                    #settings.commit()
            else:
                node = getattr(settings.node, gateway_node)
                if node.mac != m:
                    err("MAC mismatch: %s, %s", node.mac, m)
                    sys.exit()
                assert 'domain' in node
                domain = node.domain

    ifs = parse_ifconfig()
    network = {}
    for iface, ifconf in ifs:
        if 'inet' in ifconf:
            conf = ifconf['inet']
            assert conf['ip'] not in network
            network[conf['ip']] = iface

    fqdn, aliases, addresses = socket.gethostbyname_ex(getfqdn)
    #print socket.gethostbyname_ex(hostname)
    #assert (fqdn, aliases, addresses) == socket.gethostbyname_ex(hostname)
    print "Full address:", fqdn
    print "Host aliases:"
    for alias in aliases:
        print '\t-', alias
    print "IP addresses:"
    for address in addresses:
        print '\t-', address,
        if address in network:
            print network[address]
        else:
            print

    #print 'gethostbyname_ex',socket.gethostbyname_ex('localhost.localdomain')
    #for domain in settings.domain:
    #    print domain

def main():
    """
    - check current host is known
    - check gateway is known
    - set local or mobile domain to gateway internal domain

    Once ready, print hostname or node, local domain and internet domain if
    available. Ie.:

        mybox network.internal example.net

    Domain may be 'local' while offline (no default route to internet)
    or 'mobile' for unrecognized routes/gateways.
    """

    hostname = get_hostname()
    assert hostname
    gateway = get_gateway()
    if not gateway:
    	err("No internet uplink. ")
        print hostname, 
    else:
        print hostname, gateway

if __name__ == '__main__':
    main()
