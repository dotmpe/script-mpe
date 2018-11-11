# This should not be need to can be toggled
redo test-baseline
# This runs required packages in specific order first
redo test-required
# This runs the rest, anything not tested
redo test-all
