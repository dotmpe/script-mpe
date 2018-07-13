Feature: manage checkouts

  Scenario: test
    When the user executes "vc stat"
    And the user executes "vc status"
    And the user executes "vc st"

  Scenario Outline: given repository URL, setup checkout working dir

    Given `env` 'VENDOR=github.com NS_NAME=<ns> =/srv/project-local/ GITDIR=/srv/scm-git-local/'
    And no directory path "/srv/project-local/<dir>" exists

    When the user executes "htd project checkout <ns>/<dir> <url>"

    Then a directory "/srv/project-local/<dir>/.git" exists
    And a directory "/srv/scm-git-local/<ns>/<dir>.git" exists
    #And a directory "/src/github.com/<ns>/<dir>/.git" exists

  Examples:
      | url | dir | ns | env |
      | https://github.com/bvberkum/x-gh-travis | x-gh-travis | bvberkum | |
      | dotmpe:~/domains/dotmpe.com/htdocs/git/x-go.git | x-go | | |
      | git@github.com:bvberkum/x-ci.git | x-ci | | |
      #| /srv/scm-git-local/bvberkum/script-mpe | script-mpe | | |


  Scenario Outline: init and cleanup backup repo
      
      Create local backup annex repo (/srv/backup-local in /srv/annex-local).

  Examples:
          | <env> |

