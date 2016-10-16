import array
import struct
import socket
import fcntl

"""
SIOCGIFCONF = 0x8912  #define SIOCGIFCONF
BYTES = 4096          # Simply define the byte size

# get_iface_list function definition 
# this function will return array of all 'up' interfaces 
def get_iface_list():
    # create the socket object to get the interface list
    sck = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    # prepare the struct variable
    names = array.array('B', '\0' * BYTES)
    
    # the trick is to get the list from ioctl
    bytelen = struct.unpack('iL', fcntl.ioctl(sck.fileno(), SIOCGIFCONF, struct.pack('iL', BYTES, names.buffer_info()[0])))[0]

    # convert it to string
    namestr = names.tostring()

    # return the interfaces as array
    return [namestr[i:i+32].split('\0', 1)[0] for i in range(0, bytelen, 32)]

# now, use the function to get the 'up' interfaces array
#ifaces = get_iface_list()
"""

"""
def all_interfaces():
    max_possible = 128  # arbitrary. raise if needed.
    bytes = max_possible * 32
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    names = array.array('B', '\0' * bytes)
    outbytes = struct.unpack('iL', fcntl.ioctl(
        s.fileno(),
        0x8912,  # SIOCGIFCONF
        struct.pack('iL', bytes, names.buffer_info()[0])
    ))[0]
    namestr = names.tostring()

    lst = []
    for i in range(0, outbytes, 40):
        name = namestr[i:i+16].split('\0', 1)[0]
        ip   = namestr[i+20:i+24]
        lst.append((name, ip))
    return lst

def format_ip(addr):
    return str(ord(addr[0])) + '.' + \
           str(ord(addr[1])) + '.' + \
           str(ord(addr[2])) + '.' + \
           str(ord(addr[3]))

ifs = all_interfaces()
for i in ifs:
    print "%12s   %s" % (i[0], format_ip(i[1]))
"""


import fcntl
import array
import struct
import socket
import platform

# global constants.  If you don't like 'em here,
# move 'em inside the function definition.
SIOCGIFCONF = 0x8912
MAXBYTES = 8096

def localifs():
    """
    Used to get a list of the up interfaces and associated IP addresses
    on this machine (linux only).

    Returns:
        List of interface tuples.  Each tuple consists of
        (interface name, interface IP)
    """
    global SIOCGIFCONF
    global MAXBYTES

    arch = platform.architecture()[0]

    # I really don't know what to call these right now
    var1 = -1
    var2 = -1
    if arch == '32bit':
        var1 = 32
        var2 = 32
    elif arch == '64bit':
        var1 = 16
        var2 = 40
    else:
        raise OSError("Unknown architecture: %s" % arch)
    print var1, var2

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    names = array.array('B', '\0' * MAXBYTES)
    print sock.fileno()
    print SIOCGIFCONF
    print struct.pack('iL', MAXBYTES, names.buffer_info()[0])
    outbytes = struct.unpack('iL', fcntl.ioctl(
        sock.fileno(),
        SIOCGIFCONF,
        struct.pack('iL', MAXBYTES, names.buffer_info()[0])
        ))[0]

    namestr = names.tostring()
    return [(namestr[i:i+var1].split('\0', 1)[0], socket.inet_ntoa(namestr[i+20:i+24])) \
            for i in xrange(0, outbytes, var2)]


print localifs()

