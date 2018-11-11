Feature: Htd helper for local repositories and vendorized checkout dirs

    Background:

        Given `env` 'verbosity=0'
        Given `opts` key `debug_command` 'on'
    
    Scenario: list local repositories

        When the user runs "htd gitrepo --dir=/srv/scm-git-local bvberkum/*.git"
        Then each `output` line matches the pattern '.*.git$'
        And `stderr` is empty
        And `output` has the lines:
        """
        /srv/scm-git-local/bvberkum/script-mpe.git
        /srv/scm-git-local/bvberkum/mkdoc.git
        """

    Scenario: list local repositories (defaults)

        # FIXME: need quite a setup to test or mock this more properly
        #And `vars` key `NS_NAME` 'vendor'
        When the user runs "htd show repos dir stdio_0_type NS_NAME"
        Then `output` equals:
        """
        t
        bvberkum
        """

        When the user runs "htd gitrepo"
        Then `stderr` is empty
        And `output` has the lines:
        """
        /srv/scm-git-local/bvberkum/script-mpe.git
        /srv/scm-git-local/bvberkum/mkdoc.git
        """

    Scenario: list repositories in dir and/or for glob

        When the user runs "htd gitrepo --dir=/src/github.com bvberkum/*/.git"
        Then `stderr` is empty
        And `output` has the lines:
        """
        /src/github.com/bvberkum/mkdoc/.git
        """

        When the user runs "htd gitrepo --dir=/src */*/x-meta/.git"
        Then `stderr` is empty
        And `output` has the lines:
        """
        /src/bitbucket.org/dotmpe/x-meta/.git
        """
    
    Scenario: gitrepo scripted use
        
        When the user runs "repos='foo bar' htd gitrepo"

        Then `stderr` is empty
        And `output` equals:
        """
        foo
        bar
        """
        
        When the user runs "repos='foo bar' htd gitrepo x y z"...
        Then `status` should not be '0'

    Scenario: gitrepo env and stdin

        Given `vars` key `NS_NAME` 'vendor'
        When the user runs "htd show NS_NAME"
        Then `output` equals 'vendor'

        Given `stdin` '{ echo foo; echo bar; }'
        When the user runs "htd gitrepo"

        Then `stderr` is empty
        And `output` equals:
        """
        /srv/scm-git-local/vendor/foo
        /srv/scm-git-local/vendor/bar
        """

