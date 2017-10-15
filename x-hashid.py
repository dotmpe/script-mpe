from __future__ import print_function
from hashids import Hashids

hashids = Hashids(salt="this is my salt")
id = hashids.encode(1, 2, 3)
numbers = hashids.decode(id)
print(id)
