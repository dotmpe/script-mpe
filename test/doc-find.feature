Feature: Find document(s)

    Background: given a local context it should be possible to list all documents, and specific documents in that context. To order the results various levels of metadata might be required, for simplicity

    Scenario Outline: given either or both a name and content match pattern, give the matching documents ordered by priority

        When the user runs "echo"..

        Examples:
            | foo | bar |
            | 1 | 2 |
