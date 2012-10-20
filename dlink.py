#!/usr/bin/python
"""
Double link.

 $ dlink link-path
 ln -s link-path link-target.link.n

"""

import sys, os


def main():
	cwd = os.getcwd()
	args = list(sys.argv[1:])
	assert 0 < len(args) < 3
	link = None
	if len(args) == 2:
		link = args.pop()
	target = args.pop(0)
	if target[-1] == os.sep:
		target = target[:-1]
	backlink = target + '.link'
	count = 0
	while os.path.exists(backlink) or os.path.islink(backlink):
		assert os.path.islink(backlink), backlink
		count += 1
		backlink = "%s.%s.%i" % (target, 'link', count)
	assert not os.path.islink(backlink)
	if not link:	
		link = os.path.join(cwd, os.path.basename(target))
	if not ( os.path.exists(link) or os.path.islink(link)):
		os.symlink(target, link)
	os.symlink(link, backlink)

if __name__ == '__main__':
	main()
