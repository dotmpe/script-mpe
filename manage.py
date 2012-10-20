#!/usr/bin/env python
from migrate.versioning.shell import main

if __name__ == '__main__':
	main(url='sqlite:////home/berend/.cllct/db.sqlite', debug='False', repository='cllct')
