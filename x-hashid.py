#!/usr/bin/env python
from __future__ import print_function
from hashids import Hashids

if __name__ == '__main__':
    hashids = Hashids(salt="this is my salt")
    id = hashids.encode(1, 2, 3)
    numbers = hashids.decode(id)
    print(id)
