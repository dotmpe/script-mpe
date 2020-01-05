Feature: manage checkouts
  - Create checkout
  - Update checkout
  - Cleanup checkout

  Scenario Outline: given repository URL, setup checkout working dir
    - Given a directory "/srv/project-local/<dir>" doesn't exist
    - When the user executes "echo <env> htd ... create <url> <dir>"...
    - Then a directory "/srv/project-local/<dir>/.git" exists
    - #Then a checkout "/srv/project-local/<dir>" exists

  Examples:
    | url | dir | env |
    | https://github.com/dotmpe/x-gh-travis | x-gh-travis | |
    | dotmpe:~/domains/dotmpe.com/htdocs/git/x-go.git | x-go | |
    | git@github.com:dotmpe/x-ci.git | x-ci | |

    .. /srv/scm-git-local/dotmpe/script-mpe

  Scenario Outline: init and cleanup backup repo
    Create local backup annex repo (/srv/backup-local in /srv/annex-local).

  Examples:
    | <env> |

