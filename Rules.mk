# Non recursive make, partial rule file. See github mkdocs.
include                $(MK_SHARE)Core/Main.dirstack.mk
MK                  += $/Rules.mk
#
#      ------------ -- 

STRGT               += test_py_$d test_sa_$d

ifneq ($(call contains,$(MAKECMDGOALS),clean),)
CLN                 += $(shell find ./ -iname '*.pyc')
endif
#      ------------ -- 

GIT_$d              := $(shell find "$d" -iname ".git")
BZR_$d              := $(shell find "$d" -iname ".bzr")
HG_$d               := $(shell find "$d" -iname ".hg")
co::
	@$(call log_line,info,$@,Trying to update..)
	@$(clean-checkout)
co:: DIR := $d

#      ------------ -- 

REPO=cllct
DB_SQLITE_TEST=.test/db.sqlite
DB_SQLITE_DEV=/home/berend/.$(REPO)/db.sqlite

$(eval $(shell [ -d $/.build ] || mkdir $/.build ))


###    Test targets
#
#      ------------ -- 

test:: test_py_$d test_sa_$d

test_py_$d test_sa_$d :: D := $/

# Generate a coverage report of one or more runs to find stale code
debug_py_$d:: TESTS := 
debug_py_$d::
	@$(call log_line,info,$@,Starting python unittests..)
	@\
		COVERAGE_PROCESS_START=.coveragerc \
			$(TEST_DATA) ./system-test $(TESTS) \
				2>&1 | tee systemtest.log
	@\
		PASSED=$$(echo $$(grep PASSED systemtest.log | wc -l));\
		ERRORS=$$(echo $$(grep ERROR systemtest.log | wc -l));\
		echo $$PASSED passed checks, $$ERRORS errors, see systemtest.log
#		PYTHONPATH=$$PYTHONPATH:./;\
#		PATH=$$PATH:~/bin;\
#        TEST_PY="main.py txs:ls cmd:targets cmd:help";\
#		TEST_LIB=cmdline,target,res,txs,taxus,lind,resourcer;\
#		HTML_DIR=debug-coverage;\
#		VERBOSE=2;\
#    $(test-python) 2> debug.log
#	@if [ -n "$$(tail -1 debug.log|grep OK)" ]; then \
#	    $(ll) Success "$@" "see" debug.log; \
#    else \
#	    $(ll) Errors "$@" "$$(tail -1 debug.log)"; \
#	    $(ll) Errors "$@" see debug.log; \
#    fi

# Unit test python code
test_py_$d::
	@$(call log_line,info,$@,Starting python unittests..)
	@\
		PYTHONPATH=$$PYTHONPATH:./;\
		PATH=$$PATH:~/bin;\
		TEST_PY=test.py;\
		TEST_LIB=confparse,confparse2,taxus,rsr,radical,workLog;\
		HTML_DIR=test-coverage;\
		VERBOSE=2;\
    $(test-python) 2> test.log
	@if [ -n "$$(tail -1 test.log|grep OK)" ]; then \
	    $(ll) Success "$@" "see" test.log; \
    else \
	    $(ll) Errors "$@" "$$(tail -1 test.log)"; \
	    $(ll) Errors "$@" see test.log; \
    fi

# Make SA do a test on the repo
test_sa_$d::
	@$(call log_line,info,$@,Testing SQLAlchemy repository..)
	@\
	DBREF=sqlite:///$(DB_SQLITE_TEST);\
	sqlite3 $(DB_SQLITE_TEST) ".q"; \
	python $D$(REPO)/manage.py test --repository=$(REPO) --url=$$DBREF

sa-migrate-init::
	./manage.py version_control
	@echo Remember to set DB version to schema or schema-1.
	sqlite3 ~/.cllct/db.sqlite

sa-upgrade::
	./manage.py upgrade

sa-t::
	@\
	DB_VERSION=$$(./manage.py db_version);\
	SCHEMA_VERSION=$$(./manage.py version);\
	echo '"""' > oldmodel.py;\
	./manage.py compare_model_to_db taxus:metadata >> oldmodel.py;\
	echo '"""' >> oldmodel.py;\
	./manage.py create_model >> oldmodel.py;\
	./manage.py make_update_script_for_model \
		--oldmodel=oldmodel:meta \
		--model=taxus:metadata \
			> cllct_automigrate_$$SCHEMA_VERSION.py

stat::
	@\
    $(call log,header2,Repository,$(REPO) [$(DB_SQLITE_DEV)]);\
    SCHEMA_VERSION=$$(python $(REPO)/manage.py version $(REPO));\
    $(call log,header2,Repository version,$$SCHEMA_VERSION);\
    DB_FORMAT=$$(file -bs $(DB_SQLITE_DEV));\
    $(call log,header2,DB format,$$DB_FORMAT);\
	DBREF=sqlite:///$(DB_SQLITE_DEV);\
    DB_VERSION=$$(python $(REPO)/manage.py db_version $$DBREF $(REPO));\
    $(call log,header2,DB schema version,$$DB_VERSION);\
    [ -e manage.py ] || migrate manage manage.py --repository=$(REPO) --url=$$DBREF


#      ------------ --
#
include                $(MK_SHARE)Core/Main.dirstack-pop.mk
# vim:noet:
