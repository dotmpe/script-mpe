

     Feature: track scripts in plain-text table

  Background: some docstat thing but for scriptfiles. Create plain text table rows to track Scr-ID, c/mtime, label and tags for script files and commands.

       Given the current project
       Given clean temp. "scrtab-feature-testdir-*"
       Given `vars` key `SCRTAB` 'scrtab.list'
       Given `vars` key `SCRDIR` 'scr.d'
      #Given `vars` key `verbosity` '5'
         And `env` '. $project_dir/util.sh && lib_load && lib_load setup-sh-tpl'
       Given the current script directory
      #Given `opts` key `debug_output` 'on'
      #Given `opts` key `debug_stderr` 'on'

    Scenario: can add new script, track times and parse result, and update

       Given 'scrtab-feature-testdir-a' setup from 'test/var/scrtab-tpl-a.sh'
       Given `vars` key `new_ctime` '1539038820'
       Given `vars` key `new_short` "Some script" 

        When the user runs `htd scrtab new test-script.sh`
        
        Then file 'scrtab.list' lines equal:
"""
# status ctime     mtime            script-id         label         @ctx        <src>
0 20181009-0047+02 20181009-0048+02 test-script-1 Some script @Std <TEMP:scrtab-feature-testdir-a/scr.d/test-script-1.sh>
"""
         And a file 'scr.d/test-script-1.sh' exists
        
        When the user runs `htd scrtab scr-show test-script-1 scr_file`
        Then `output` should match '.*\/scr\.d\/test-script-1\.sh'

        # Lets invalidate the script
        When the user runs `echo "error - line" > scr.d/test-script-1`
         And the user runs `htd scrtab update --process --verbosity=6 test-script-1`
         And user executes `tail -n 1 scrtab.list`
        Then `output` matches:
"""
255 20181009-0047+02 .* test-script-1 Some script @Std <TEMP:scrtab-feature-testdir-a/scr.d/test-script-1.sh>
"""

        # TODO: test mtime field
        #When the user runs `touch $(htd scrtab scr-show test-script-1 scr_file)`
        
        Then back to current project dir
         And drop temp. dir 'scrtab-feature-testdir-a'

@skip
    Scenario: can add new command with no script file

      #Given temp dir 'scrtab-feature-testdir-2'
       Given 'scrtab-feature-testdir-2' setup from 'test/var/package-empty-project-tpl.sh'
        When the user runs `htd package update`

       Given `vars` key `new_short` "Print username" 
        When the user runs `htd scrtab new '' 'whoami'`
        Then tests 'htd scrtab entry-exists std-berend-notus-1' ok
         And test 'test ! -e scr.d/std-berend-notus-1.sh || { ls -la $SCRDIR ; cat $SCRTAB ; false ; }'
        # FIXME And not tests 'htd scrtab entry-exists std-berend-notus-2' ok
         And tests 'htd scrtab entry-exists std-berend-notus-2 && false || true' ok
        
@skip
    Scenario: can add scripts in-situ, without moving
       Given temp dir 'scrtab-feature-testdir-3'
        When the user runs `htd scrtab ...`

@skip
    Scenario: can update record fields: label, tag, and create aliases, groups and sequences
       Given 'scrtab-feature-testdir-4' setup from 'test/var/scrtab-tpl-2.sh'
       Given `vars` key `new_short` "New title" 
        When the user runs `htd scrtab update test-script-2`
        Then file 'scrtab.list' lines equal:
"""
# status ctime     mtime            script-id         label         @ctx        <src>
- 20181009-0047+02 20181009-0048+02 test-script-1 Some script @Std <TEMP:srctab-feature-testdir-4/scr.d/test-script-1.sh>
- 20181009-0047+02 20181009-0041+02 test-script-2 New title @Std <TEMP:srctab-feature-testdir-4/scr.d/test-script-2.sh>
"""

        Then back to current project dir
        Then drop temp. dir 'scrtab-feature-testdir-4'

        # TODO: test tag modes, look at aliasing or audit trail for renames
