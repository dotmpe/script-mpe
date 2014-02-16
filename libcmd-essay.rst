:created: 2014-01-16

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





