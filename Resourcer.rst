Resources [rsr] - python command line file manager

related to Taxus - python relational storage

TODO: reinvent rsr using script libs
	- x-meta screenscraper required some universal resource loader
	  for python which resulted in rsr. 
	  Project stalled while difficult or intricate laborious tasks where not finished
	  most importantly a). some universal storage layer and a reasonbly mature set
	  of domain object types, and b). a mature and convenient \*NIX
	  configuration and command line invocation framework.

	  E.g. script-mpe/confparse should load settings at various custom or default points 
	  in the filesystem, merge those and possibly allow for overrides (cascading), and
	  also allow for rewriting. 

	  Also script-mpe/taxus has has taken to implement the domain part using
	  SQLAlchemy. 
	  
	  Possibly both could result in tools to think about more universal storage
	  adapters, distributed across SQL and NoSQL and other assorted formats.

	  Then.. think N3, CWM.

TODO: where to store settings, data; need split-settings/composite-db

TODO: URN ID's to use in htdocs, taxus and tree-mpe.
   urn:dotmpe:disk:%(hex_disk_id)s:%(hostname)s:%(device_name)s[%(disk_numbers)]


   
Attributes for Metadir.find and subclasses:

========= ========= ===========
class     dotdir    dotdir_id 
========= ========= ===========
Metadir   meta      dir
Workspace cllct     ws
Volume    (id.)     vol
========= ========= ===========

This leads to metafiles using confparse's find_config_path heuristics.

XXX: These are not used by libcmd.load_config yet, subcommands can used them




