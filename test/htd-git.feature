Feature: GIT helpers (in htd)

    Scenario: list local repositories

        When the user runs "verbosity=0 htd gitrepo"
        Then each `output` line matches the pattern '.*.git$'
        Then `output` has the lines:
        """
        /srv/git-local/bvberkum/script-mpe.git
        /srv/git-local/bvberkum/mkdoc.git
        """

    Scenario: list repositories in dir and/or for glob

        When the user runs "htd gitrepo --dir=/src/github.com bvberkum/*/.git"
        Then `output` has the lines:
        """
        /src/github.com/bvberkum/mkdoc/.git
        """

        When the user runs "htd gitrepo --dir=/src */*/x-meta/.git"
        Then `output` has the lines:
        """
        /src/bitbucket.org/dotmpe/x-meta/.git
        """
    
    Scenario: gitrepo scripted use
        
        When the user runs "repos='foo bar' htd gitrepo"
        Then `output` equals:
        """
        foo
        bar
        """
        
        When the user runs "repos='foo bar' htd gitrepo x y z"...
        Then `status` should not be '0'

    Scenario: gitrepo stdin

        When the user runs "{ echo foo; echo bar; } | NS_NAME=vendor htd gitrepo"
        Then `output` equals:
        """
        /srv/git-local/vendor/foo
        /srv/git-local/vendor/bar
        """

    #Scenario: git grep
        
        #When the user runs "htd git-grep -C='$(vc list-local-branches)' fs-casematch"
        #When the user runs "C='$(vc list-local-branches)' htd git-grep fs-casematch"

