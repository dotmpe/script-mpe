# Non recursive make, partial rule file. See github mkdocs.
include                $(MK_SHARE)Core/Main.dirstack.mk
MK                  += $/Rules.mk
#
#      ------------ -- 


GIT_$d              := $(shell find "$d" -iname ".git")
BZR_$d              := $(shell find "$d" -iname ".bzr")
HG_$d               := $(shell find "$d" -iname ".hg")
co::
	@$(call log_line,info,$@,Trying to update..)
	$(clean-checkout)
co:: DIR := $d


test::
	@$(call log_line,info,$@,Starting tests..)
	@\
		PYTHONPATH=$$PYTHONPATH:./;\
		PATH=$$PATH:~/bin;\
		TEST_PY=test.py;\
		TEST_LIB=confparse,confparse2,taxus,rsr,radical,workLog;\
		VERBOSE=2;\
    $(test-python)


#      ------------ --
#
include                $(MK_SHARE)Core/Main.dirstack-pop.mk
# vim:noet:
