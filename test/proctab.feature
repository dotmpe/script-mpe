Feature: execute scripts

    Background: record execution contexts for scripts (see scrtab) in table, execute and/or control schedule, and trackr result.

    Scenario: can select scripts by CWD, env or other field, and execute script in proper context

        When the user runs `htd procstat run @Std`

    Scenario: can add script..
        When the user runs `htd procstat new test-script.sh`
