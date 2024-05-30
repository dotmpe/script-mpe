#!/usr/bin/python
""" Golden ratio app """

import sys, math

cphi='φ'
phi = ( 1 + math.sqrt(5) ) / 2

args = sys.argv[1:]
if len(args) > 0:
  i = float(args[0])
  U = i * phi
  u = i / phi # * (1/phi)
  print(f"{cphi} {i}\t{U}")
  print(f"1/{cphi} {i}\t{u}")
else:
  print(f"{cphi}\t{phi}")
  print(f"1/{cphi}\t"+str(1/phi))
