"""
"serve" over FIFO is an interesting idea, but how to do feedback properly.
Probably a log file.
"""
from __future__ import print_function
import os
import select

FIFO_PATH = '_fifo_in'
os.mkfifo(FIFO_PATH)
os.mkfifo('_fifo_out')

lines = 0
try:
    with open(FIFO_PATH, 'r') as fifo, open('_fifo_out', 'w') as out:
        while True:
            select.select([fifo],[],[fifo])
            data = fifo.read().strip()
            if data == 'exit':
                print('exit called')
                fifo.close()
                out.close()
                break
            if data:
                print(data)
                lines += 1
                print(lines, file=out)
except KeyboardInterrupt as e:
    pass

print("Stopped after %i lines" % lines)
os.unlink(FIFO_PATH)
os.unlink('_fifo_out')
