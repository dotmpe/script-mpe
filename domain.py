#!/usr/bin/python
"""Local Domain Scan
=================
Identify local and remote boxes and current network.

- Every box is considered a network node with one or more NIC.
- All boxes use a hostname as primary identifier. 
- Every network is a set of permanent and 'roaming' NIC.

Future
-------
- Current local network is identified by gateway interface (by MAC address).
- Nodes may be identified by SSH key (or PGP?).
- All local network addresses are mapped.
- Then a ip-hostname lookup table is build.
- http://muthanna.com/quickswitch/ would be a nice tool to do the actual 
  host/interfaces/... config switching.
- Global online status is by PING to some known server. Perhaps Google, perhaps
  some DNS or even a more appropiate server?
  
Settings
---------
- YAML, rewritten on update.
- FIXME: Contains generated nodes.
  Better keep dynamic values separated.

:Schema:
	``node`` a Map<Str,Node>
		`host-id`
			``host``: `HostName`
			``interface``: 
				- `HardwareAddress`
	``network`` a Map<Str,Network>
		`net-id`
			``name``: `NetworkName`
			``nodes``: 
				- `HardwareAddress` a Node
			``routes``: 
				- `HardwareAddress` a Gateway
	``domain`` a Tree<Str,Domain>
		- `tld`
			- `name`
				- ``net``: `net-id`
				  ``ipv4``: `ip`
				
				- `sub`
					``net``: `net-id`
					``ipv4``: `ip`

:Dynamic:
	``interfaces``
		`HardwareAddress`: `host-id`
	``nodes``
		`HardwareAddress`: `net-id`
	``hosts``
		`ip`:
			``fqdn``: `domain`
			``aliases``:
				- `host-id`
			

# TODO: build gateway from 
	``gateways``
		`HardwareAddress`
			``internal``: `net-id`
			``external``: `ip`

scrap
------
node:
  wrt54g2.lan:
  orb:
  iris:
  maelstrom:
  sam:
  pandora:
	- name: en0
	  ether: 10:9a:dd:4c:d5:a8 
	- name: en1
	  ether: c8:bc:c8:ed:be:c1 
  midway:
  brixmaster:
  dotmpe: 109.72.86.5
  brixcrm.com: 212.79.236.226
  brixcrm.nl: 89.105.210.233
  brixnet.nl: 89.105.204.141
  oostereind: 83.119.152.57

domain:
  brix:
	brixmaster: {}
	pandora: {}
  com:
	brixcrm: {}
	dotmpe:
	  htdocs:
		bzr: {}
		cms: {}
		dist: {}
		git: {}
		project: {}
		services: {}
		usr: {}
		www: {}
  mobile:
	moto: {}
	pandora: {}
	sam:
	  htdocs:
		facio: {}
		usr: {}
  nl:
	brixcrm: {}
	brixnet: {}
  oostereind:
	iris: {}
  pandora:
	andromeda: {}
	clamshell:
	  htdocs:
		facio: {}
		usr: {}
"""
import datetime
import os
from pprint import pformat
import re
import socket
import sys

import yaml

import confparse


config = confparse.expand_config_path('cllct.rc')
"Configuration filename."

settings = confparse.load_path(*config)
"Static, persisted settings."

def reload():
	global settings
	settings = settings.reload()
	if 'dynamic' not in settings:
		settings['dynamic'] = []
	# Reparse interfaces
	settings['interfaces'] = confparse.Values({}, root=settings)
	for host in settings.node:
		for mac in settings.node[host].interface:
			assert mac not in settings.interfaces
			settings.interfaces[mac] = host
	if 'interfaces' not in settings.dynamic:
		settings.dynamic.append('interfaces')
	# Reparse nodes
	settings['nodes'] = confparse.Values({}, root=settings)
	for network in settings.network:
		for mac in settings.network[network].nodes:
			assert mac not in settings.nodes
			settings.nodes[mac] = network
	if 'nodes' not in settings.dynamic:
		settings.dynamic.append('nodes')

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
	"""
	Return MAC for IP address (as reported by ARP).
	"""
	a = get_dest_info(addr)
	try:
		return a.next()[3]
	except StopIteration, e:
		return


def assert_node(host, mac):
	global settings
	if host not in settings.node:
		node = {
			'host': host,
			'interface': [mac],
		}
		settings.node[host.lower()] = node
		settings.commit()
		reload()
		print 'Added new node: `%s <%s>`_' % (host, mac)

def _old_2():
	global settings
	if mac not in settings.node:
		print """
Unknown Interface
-----------------
Found an unknown node: %s.

For most boxes, this interface will be permanently connected to one network.
But if this node is mobile, it may belong to more than one network.
""" % (mac,)
		v = raw_input("Mobile? [yN] ")
		if v != None or v.lower() != 'n':
			pass #
		print """
Enter an ID for this network. If the network ID alreay
exists, the interface will be listed in the nodes for this network. Otherwise a
new network is created.
"""
		
		network_id = raw_input("Network ID? [a-z][a-z0-9]*")
		if network_id not in settings.network:
			v = raw_input("Insert new network? [Y|n] ")
			if v != None or v.lower() != 'y':
				return
			settings.network[network_id] = {
					'domain': None,
					'nodes': [ mac ] }
		settings.node[mac] = {
				'net': network_id }
		settings.commit()
		settings = settings.reload()

		print 'Added new node: %s' % mac

def _old_1(host):
	if host not in settings.node:
		addr = socket.gethostbyname(host)
		node = {
			'mac': get_mac(addr),
			'ip': addr,
		}
		#setattr(settings.node, host, confparse.Values(node,root=settings.node))
		settings.node[host] = confparse.Values(node,root=settings.node)
		assert isinstance(settings.copy()['domain']['brix']['brixmaster'],
				dict), pformat(settings.copy()['domain']['brix'])
		assert not isinstance(settings.copy()['domain']['brix']['brixmaster'], confparse.Values)
		print 'Adding', host, node
		#settings.commit()
		#settings = settings.reload()

def assert_gateway(node):
	return
	assert 'domain' in node
	assert 'local' in node

from rsrlib.plug.net import get_hostname, get_gateway

def info():
	"""
	determine gateway, and identify node by hardware address
	record new gateways
	"""

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
	#	print domain

def get_current_node():
	global settings

	host = get_hostname()
	assert host
	addr = socket.gethostbyname(host)
	assert addr, host
	ifinfo = parse_ifconfig()
	mac = None
	for iface, attr in ifinfo:
		if 'inet' in attr:
			if 'ip' in attr['inet']:
				mac = attr['mac']
				break
	#if not mac: # XXX:?
	#	mac = get_mac(addr)
	assert mac, addr
	assert_node(host, mac)
	host = settings.node[host]['host']
	assert host
	return host, addr, mac

NS_NET = '//wtwtg.org/taxus/network#'
NS_NET_ID = 'urn:org.wtwtg.org:taxus:network#'
NS_ = 'taxus:Network'


def network_name(network_id):
	global settings

	network = settings.network[network_id]
	if 'name' in network:
		return "`%s <%s%s>`" % (network['name'], NS_NET, network_id)
	else:
		return "<%s%s>" % (NS_NET, network_id)

def main():
	"""
	- check current host is known
	- check gateway (default route) is known
	- set local or mobile domain to gateway internal domain

	Once ready, print hostname or node, local domain and internet domain if
	available. Ie.:

		example network.internal example.net

	Domain may be 'local' while offline (no default route to internet)
	or 'mobile' for unrecognized routes/gateways.
	"""
	global settings

	print """
Local domain check
==================
:Date: %s """ % datetime.datetime.now().isoformat()

	host, addr, mac = get_current_node()
	print ':Host: `%s <%s>`' % (host, mac)

	gateway, gateway_mac, gateway_addr = get_gateway()
	print ':Gateway: `%s <%s>`' % (gateway, gateway_mac)

	network_id = settings.nodes[gateway_mac]
	network = network_name(network_id)

	print ':Network:', network

	if not gateway:
		err("No internet uplink. ")
		print host, 'local'
	else:
		pass#print host, gateway

	#print 'ifinfo', pformat(ifinfo)

	settings.commit()
	reload()

if __name__ == '__main__':
	reload()
	main()
