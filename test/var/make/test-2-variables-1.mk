
# mkvar assignment II - Expansion tests

# Expand to foo foo foo
VAR1_1a    =    $(VAR1a)
VAR1a      =    foo
VAR1_1b    =    $(VAR1a)

# Expand to '' foo foo
VAR1_2a    :=    $(VAR1b)
VAR1b      :=    foo
VAR1_2b    :=    $(VAR1b)

default:: ;
dump::
	@echo VAR1_1a=$(VAR1_1a)
	@echo VAR1a=$(VAR1a)
	@echo VAR1_1b=$(VAR1_1b)
	@echo
	@echo VAR1_2a=$(VAR1_2a)
	@echo VAR1b=$(VAR1b)
	@echo VAR1_2b=$(VAR1_2b)

