Feature: paths can be named by prefix, and each local name tracked when opened


    Prefixes allow to shorten deep paths to more managable size, and can allow
    for a way to deal cross-host with local paths representing the same
    entities, ie. project checkouts, default service config or data locations,
    and whatever comes to the imagination.

    Iow. we write (almost) global ID's, but refer to local paths. E.g.

        HOME:public_html/

    which is entirely clear what it represents. The user homedir is not the best
    usage (since we have a far shorter prefix for that), but prefixes are
    entirely user defined.

    Definitions are conveniently kept in an shell template at
    UCONF:pathnames.tab, which generates a mapping for path to prefix, for
    whatever local env and paths there is. The first line is considered the
    default or canonical path, use to expand into. While several lines can
    exist, and to Htd-prefixes it does not matter wether these are actually
    distinct paths or symbolic variants of the same location.


    Scenario: given a definition I can either shorten and expand any path

        When the user executes "htd prefixes raw-table"...
        Then `output` has:
        """
        / ROOT
        $HOME/ HOME
        """
        # TODO: to make life easier, supplement pathnames.tab and env
        #$HOME/htdocs HT ie. scan for HTDIR and use HT prefix.
        And `status` is "0"

        When the user executes "htd prefixes table"
        Then `output` contains:
        """
        [A-Za-z0-9\._-]+:\/ ROOT
        [A-Za-z0-9\._-]+:\/Users\/berend\/ HOME
        """

        When user runs "htd prefixes expand UCONFDIR:pathnames.tab"
        Then `output` matches '.*\/.conf\/pathnames.tab'

        When the user runs "htd prefixes name $HOME/bin"
        Then `output` is 'HOME:bin/'

        When the user runs "htd prefixes names $HOME $HOME/bin $HOME/.conf"
        Then `output` has:
        """
        HOME:
        HOME:bin/
        UCONF:
        """


    Scenario: for any path I can list current open files
        
      Aside from a local mapping of paths and IDs, Htd-prefixes helps to record
      open paths over the course of time.

        When the user executes "htd prefixes op"
      # Then the output all lists paths attached to shells (ie. CWD/PWD).
      # With htd_act on prints a + for lines updated within the last hour,
      # or a - for those older.
        Then each `output` line matches '[A-Z][A-Za-z0-9_]+:.*'

        #When the user executes "htd prefixes update"
        #When the user executes "htd prefixes current"
        # Then paths are put into redis, and removed if still open but unchanged
        # after an hour
