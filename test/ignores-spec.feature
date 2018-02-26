Feature: ignores - glob lists for paths and files

    Scenario: custom dotfile with glob groups

        # For more dotfiles init allows custom extensions to glob dotfile's name,
        # and also preselecting different glob groups per dotfile ext.

        When user runs:
        """
        lst init-ignores .names global-clean global-purge
        """
        Then `output` has more than or equal to 10 lines
        Then `output` has not less than 10 lines
        Then `output` has more than 9 lines
        Then `output` has not less than or equal to 9 lines
