:created: 2014-01-16
:updated: 2015-05-26 2017-09-04

- <https://stackoverflow.com/questions/2461702/why-is-ioc-di-not-common-in-python>
- <https://pypi.python.org/pypi/dependency_injector/>

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






