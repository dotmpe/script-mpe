
1. Regression in radical.py::

		Traceback (most recent call last):
			File "/Users/berend/bin/./radical.py", line 1234, in <module>
				Radical.main()
			File "/Users/berend/bin/libcmd.py", line 456, in main
				self.execute( handler_name )
			File "/Users/berend/bin/libcmd.py", line 516, in execute
				for res in g:
			File "/Users/berend/bin/libcmd.py", line 78, in start
				for r in ret:
			File "/Users/berend/bin/rsr.py", line 319, in rsr_session
				repo_root = session.context.settings.data.repository.root_dir
		AttributeError: 'dict' object has no attribute 'data'

	- Radical broken after 449ea4f, fork and build unittest
  - Fixed (tests/bugs/1-radical-regression) by ignoring session.context

