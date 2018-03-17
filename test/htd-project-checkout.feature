Feature: manage checkouts

  Scenario: test
    When the user executes "vc stat"
    And the user executes "vc status"
    And the user executes "vc st"

  @todo
  Scenario Outline: given repository URL, setup checkout working dir

      Given `env` '<env> PDIR=/srv/project-local/ SRCDIR=/src/ GITDIR=/srv/git-local/'
      And no directory path "/srv/project-local/<dir>" exists
      When the user executes "echo <env> htd ... create <url> <dir>"...
      Then a directory "/srv/project-local/<dir>/.git" exists

  Examples:
      | url | dir | env |
      | https://github.com/bvberkum/x-gh-travis | x-gh-travis | |
      | dotmpe:~/domains/dotmpe.com/htdocs/git/x-go.git | x-go | |
      | git@github.com:bvberkum/x-ci.git | x-ci | |
      #| /srv/git-local/bvberkum/script-mpe | script-mpe | |


  Scenario Outline: init and cleanup backup repo
      
      Create local backup annex repo (/srv/backup-local in /srv/annex-local).

  Examples:
          | <env> |

