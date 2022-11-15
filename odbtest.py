#!/usr/bin/env python3
import obd
from obd import OBDStatus

from itertools import chain
import os, sys
args = sys.argv[1:]


DEBUG = int(os.getenv('DEBUG', '0'))
if DEBUG:
    obd.logger.setLevel(obd.logging.DEBUG)


QUIET = int(os.getenv('QUIET', '0'))
if QUIET:
    obd.logger.removeHandler(obd.console_handler)


print("PyOBD/%s" % obd.__version__)

#ports = obd.scan_serial()
#print("Ports: %s" % ports)

con = obd.OBD(timeout=0.5, fast=False) # auto-connects to USB or BT port

print("Conn port: %s" % con.port_name())

if con.status() != OBDStatus.CAR_CONNECTED:
    print("No connection to car")
    print("Conn stat: %s" % con.status())
else:
    print("Conn stat: %s" % con.status())
    print("Proto name: %s" % con.protocol_name())
    print("Proto id: %s" % con.protocol_id())
    #print("Commands:")
    #con.print_commands()
    #print("Supported: %s" % con.supported_commands)

    #r = con.query(obd.commands[1][0])
    #print(r.time, r.command, r.messages)
    #print("Value: %s" % r.value)

    if '-a' in args:
        for cmdid in chain(range(0x1, 0x19), range(0x21, 0x39), range(0x41, 0x59)):
            cmd = obd.commands[1][cmdid]
            res = con.query(cmd)
            if not res.is_null():
                print(hex(cmdid), cmd.name, res)

    else:
        def by_cmd(obdcmd):
            return obdcmd.name

        #for cmd in con.supported_commands:
        for cmd in sorted(con.supported_commands, key=by_cmd):
            #print(dir(cmd))
            res = con.query(cmd)
            print(cmd.command, cmd.name, res)
            #if not res.is_null():
            #    print(cmd.command, cmd.name, res)



#cmd = obd.commands.SPEED # select an OBD command (sensor)

#response = connection.query(cmd) # send the command, and parse the response
#
#print(response.value) # returns unit-bearing values thanks to Pint
#print(response.value.to("mph")) # user-friendly unit conversions
