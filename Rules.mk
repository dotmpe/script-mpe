include                $(MK_SHARE)Core/Main.dirstack.mk
MK                  += $/Rules.mk
#
#      ------------ -- 


co::
	@$(call log_line,info,$@,Trying to update..)
	@\
		VERBOSE=$(VERBOSE);\
	\
	$(ll) done 


test::
	@$(call log_line,info,$@,Starting tests..)
	@\
		PYTHONPATH=$$PYTHONPATH:./;\
		PATH=$$PATH:~/bin;\
		TEST_PY=confparse_test.py;\
		TEST_LIB=confparse;\
		VERBOSE=2;\
    $(test-python)


#      ------------ --
#
include                $(MK_SHARE)Core/Main.dirstack-pop.mk
# vim:noet:
