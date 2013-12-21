"""
- Store path to topic mappings locally, JSON.
- Perhaps temporary name FileMap, FileTopicMap.. etc. See treemap. fstreemap?
  treemap -fs blah..
"""
from taxus import Node


class FileTreeTopic(Node):

	"""
	"""


class TopicTreeFe(libcmd.SimpleCommand):

	"""
	Construct Topic trees from file system paths.
	"""

	DEFAULT_ACTION = 'run'

	def get_opts(self):
		return Taxus.get_opts(self) + ()

	def run(self, *args, **opts):
		pass
