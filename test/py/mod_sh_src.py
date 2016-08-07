import unittest
import os, sys

from nose_parameterized import parameterized

import deep_eq
from script_mpe import sh_switch


class ShSwitchTest(unittest.TestCase):


    @parameterized.expand([
        ( "test/var/sh-src-1.sh", [
                ( ( 1, 2 ), ( 118, 9 ) ),
            ] ),
        ( "test/var/sh-src-2.sh", [ ] ), # empty file
        ( "test/var/sh-src-3.sh", [
                ( ( 66, 6 ), ( 167, 13 ) ),
                ( ( 1, 2 ), ( 228, 18 ) ),
            ] ),
    ])
    def test_sh_src_switch_get_offsets(self, shfilename, expected_ranges ):
        self.reader = sh_switch.SwitchReader( shfilename )
        offsets = list(self.reader.get_offsets())
        for start, end in offsets:

            try:
                at_idx = expected_ranges.index((start, end))
            except ValueError, e:
                self.fail("Unexpected offsets: %r, %r" % (start, end))
                continue

            del expected_ranges[at_idx]

        assert not expected_ranges


    @parameterized.expand([
        ( "test/var/sh-src-1.sh", [
            {'"$TEST_EXPR"': [ '"$MATCH_1_1" | "$MATCH_1_2"',
                '"$MATCH_2_1" | "$MATCH_2_2"' ]}
        ] ),
        ( "test/var/sh-src-2.sh", [ ] ), # empty file
        ( "test/var/sh-src-3.sh", [
            { "\"$TEST_EXPR\"": [
                "\"$MATCH_1_1\" | \"$MATCH_1_2\"",
                "\"$MATCH_2_1\" | \"$MATCH_2_2\"" ] },
            { "\"$TEST_EXPR_1\"": [ "MATCH_A", "MATCH_B", "*" ] }
        ] ),
    ])
    def test_sh_src_switch_get_raw_sets(self, shfilename, expected_sets ):
        self.reader = sh_switch.SwitchReader( shfilename )
        raw_sets = self.reader.get_raw_sets()
        for switch in raw_sets:
            idx = 0
            for idx, exp_switch in enumerate(expected_sets):
                if deep_eq.deep_eq( switch, exp_switch ):
                    del expected_sets[idx]
                    idx = 0
                    break

            if idx:
                self.fail("Unexpected raw set: %r" % switch)



# Return module test cases

def get_cases():
    return [
            ShSwitchTest,
        ]

# Or start unittest

if __name__ == '__main__':
    unittest.main()

