

     Feature: container for project metadata holds envs, script entry points
  

  Background:

        Given the current project
        Given `vars` key 'v' '6'


              @wip
    Scenario: env runs
         When the user runs `true`

        Given the current commandpath
        Given temp dir 'package-feature-testdir-b'
         When the user runs '$(env_setup) && lib_init date && setup_sh_tpl ~/bin/test/var/package-empty-project-tpl.sh'
         Then clean temp. dir 'package-feature-testdir-b'


              @wip
    Scenario: convert to JSON and extract main (update)

        Given the current commandpath
        Given 'package-feature-testdir-a' setup from 'test/var/package-empty-project-tpl.sh'
         # When the user runs '$(env_setup) && lib_init date && setup_sh_tpl \$CWD/test/var/package-empty-project-tpl.sh'
         When the user runs `tree -a && test -e package.yml`

         When the user runs `pwd -P && $(env) && mkdir -p .meta && CWD= htd.sh package update`

         #Then clean temp. dir 'package-feature-testdir-a'

#                                                                               vim:cc=14
