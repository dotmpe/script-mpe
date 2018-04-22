Feature: GIT helpers (in htd)

    Commands for getting or syncing checkouts from remote vendors, creating
    new checkouts or creating new remotes for checkouts,
    and misc. operations on checkouts.

    These are based on vc and vcflow libs.

    Some work is needed on tests and feature descriptions.
    The current suites:

    | htd-git                | bats | feature | |
    | htd-gitrepo            | | feature | |
    | htd-git-remote         | bats | | |
    | vc.lib                 | bats | | |
    | vc                     | bats | | |
    
	See also
    - htd-project-checkout

	@todo
    Scenario: git grep
        
        #When the user runs "htd git-grep -C='$(vc list-local-branches)' fs-casematch"
        #When the user runs "C='$(vc list-local-branches)' htd git-grep fs-casematch"

