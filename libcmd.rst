:created: 2014-01-16
:updated: 2017-10-02


----

libcmd.SimpleCommand
libcmd.StackedCommand

- No shared session/runtime; either run as rsr, or taxus, or cmdline.
  Ie. only access to inherited namespaces.

libcmdng

- registries for names (commands, options), specifications
  etc.


---

SimpleCommand
    NAME = 'libcmd'
    PROG_NAME = 'libcmd.py'
    #PROG_NAME = os.path.splitext(os.path.basename(__file__))[0]
    DEFAULT_RC = NAME + 'rc'
    DEFAULT_CONFIG_KEY = NAME

StackedCommand:SimpleCommand
    NAME = os.path.splitext(os.path.basename(__file__))[0]
    DEFAULT_RC = NAME + 'rc'

Cmd:StackedCommand
    NAME = 'cmd'


SimpleCommand config-path = find-config( DEFAULT_RC )
    .<rcname>.yaml
    .<name>/<rcname>.yaml
    .<name>.yaml
    .<name>/<name>.yaml

    IOptions
        ..
    IConfig
        defaults(klass)
        override(opts) <- (env, arg))

StackedCommand config-path = find-config( DEFAULT_RC )
    .<rcname>.yaml
    .<name>/<rcname>.yaml
    .<stack-name>/<rcname>.yaml # <name>

----

libcmd_docopt
    Use docopt and some globals scraping for a simple command-line program
    setup with a more or less fixed pattern::

      commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
      commands['help'] = libcmd_docopt.cmd_help

      ...

      opts = libcmd_docopt.get_opts(__doc__, version=get_version())
      settings = opts.flags
      libcmd_docopt.run_commands(commands, settings, opts)


----

Dependency patterns

- <https://stackoverflow.com/questions/2461702/why-is-ioc-di-not-common-in-python>
- <https://pypi.python.org/pypi/dependency_injector/>
