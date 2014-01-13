# Non recursive make, partial rule file. See github mkdocs.
include                $(MK_SHARE)Core/Main.dirstack.mk
MK                  += $/Rules.mk
#
#      ------------ -- 

$(eval $(shell [ -d $/.build ] || mkdir $/.build ))

#      ------------ -- 
GIT_$d              := $(shell find "$d" -iname ".git")
BZR_$d              := $(shell find "$d" -iname ".bzr")
HG_$d               := $(shell find "$d" -iname ".hg")
co::
	@$(call log_line,info,$@,Trying to update..)
	@$(clean-checkout)
co:: DIR := $d

# XXX Keep long list of clean targets out of normal stat messages
ifneq ($(call contains,$(MAKECMDGOALS),clean),)
CLN                 += .test
CLN                 += $(shell find ./ -iname '*.pyc')
CLN                 += $(shell find ./ -iname '*.log')
CLN                 += $(shell find ./ -iname '.coverage' -o -iname '.coverage-*')
endif


###    Test targets
#
#      ------------ -- 

TEST_$d             := test_py_$d  test_sa_$d  test_sys_$d 

STRGT               += $(TEST_$d)

test:: $(TEST_$d)

test_py_$d test_sa_$d :: D := $/

# Unit test python code
test_py_$d::
	@$(call log_line,info,$@,Starting python unittests..)
	@\
		PYTHONPATH=$$PYTHONPATH:./;\
		PATH=$$PATH:~/bin;\
		TEST_PY=test/main.py;\
		TEST_LIB=confparse,confparse2,taxus,rsr,radical,workLog;\
		HTML_DIR=test-coverage;\
		VERBOSE=2;\
    $(test-python) 2> test-py.log
	@if [ -n "$$(tail -1 test-py.log|grep OK)" ]; then \
	    $(ll) Success "$@" "see" test-py.log; \
    else \
	    $(ll) Errors "$@" "$$(tail -1 test-py.log)"; \
	    $(ll) Errors "$@" see test-py.log; \
    fi

# some system tests
test_sys_$d::
	@$(ll) info $@ "Starting system tests.."
	@\
	    LOG=test-system.log;\
        test/system.sh 2> $$LOG; \
    \
        PASSED=$$(grep PASSED $$LOG | wc -l); \
        FAILED=$$(grep FAILED $$LOG | wc -l); \
        [ $$FAILED -gt 0 ] && { \
            $(ll) error "$@" "$$FAILED failures, see" $$LOG; \
        } || { \
            $(ll) Ok "$@" "$$PASSED passed" $$LOG; \
        }

# Make SA do a test on the repo
DB_SQLITE_TEST=.test/db.sqlite
DB_SQLITE_DEV=/home/berend/.$(REPO)/db.sqlite
test_sa_$d::
	@$(call log_line,info,$@,Testing SQLAlchemy repository..)
	@\
	DBREF=sqlite:///$(DB_SQLITE_TEST); \
	$(ll) attention "$@" "Testing '$(REPO)' SA repo functions.." $$DBREF; \
	rm -rf $$(dirname $(DB_SQLITE_TEST));\
	mkdir -p $$(dirname $(DB_SQLITE_TEST));\
	sqlite3 $(DB_SQLITE_TEST) ".q"; \
	python $D$(REPO)/manage.py version_control --repository=$(REPO) --url=$$DBREF ;\
	db_version=$$(python $D$(REPO)/manage.py db_version --repository=$(REPO) --url=$$DBREF) ;\
	version=$$(python $D$(REPO)/manage.py version --repository=$(REPO) --url=$$DBREF) ;\
	$(ll) info "$@" "Re-created test DB.." $$DBREF; \
	python $D$(REPO)/manage.py upgrade $$(( $$version - 1 )) --repository=$(REPO) --url=$$DBREF;\
	$(ll) info "$@" "Starting at DB version: $$(( $$version - 1 ))"; \
	$(ll) info "$@" "Testing $(REPO) up/down for version: $$version"; \
	python $D$(REPO)/manage.py test --repository=$(REPO) --url=$$DBREF
	@$(ll) Done "$@" 


###    SQL Alchemy repository schema control
#
#      ------------ -- 

REPO=cllct
ALL_REPOS=cllct test
SA_DB_$d=db.sqlite

sa-reset: REPO := $(REPO)
sa-reset: 
	rm -f .$(REPO)/$(SA_DB_$d)
	make sa-migrate-init REPO=$(REPO)
	make sa-upgrade REPO=$(REPO)

sa-migrate-init:: REPO := cllct
sa-migrate-init::
	mkdir -p .$(REPO);\
	./sa_migrate/$(REPO)/manage.py version_control
	@echo Remember to set DB version to schema or schema-1.
	echo "" | sqlite3 -batch .$(REPO)/$(SA_DB_$d)
	
sa-init: sa-migrate-init

sa-upgrade::
	./sa_migrate/$(REPO)/manage.py upgrade

sa-t::
	@\
	DB_VERSION=$$(./sa_migrate/$(REPO)/manage.py db_version);\
	SCHEMA_VERSION=$$(./sa_migrate/$(REPO)/manage.py version);\
	\
	echo '"""' > oldmodel.py;\
	./sa_migrate/$(REPO)/manage.py compare_model_to_db taxus:SqlBase.metadata >> oldmodel.py;\
	echo '"""' >> oldmodel.py;\
	./sa_migrate/$(REPO)/manage.py create_model >> oldmodel.py;\
	./sa_migrate/$(REPO)/manage.py make_update_script_for_model \
		--oldmodel=oldmodel:meta \
		--model=taxus:SqlBase.metadata \
			> sa_migrate_$(REPO)_autoscript_$$SCHEMA_VERSION.py

stat:: sa-stat
sa-stat::
	@\
    $(call log,header2,Repository,$(REPO));\
    SCHEMA_VERSION=$$(python ./sa_migrate/$(REPO)/manage.py version );\
    $(call log,header2,Repository version,$$SCHEMA_VERSION);\
    DB_FORMAT=$$(file -bs $(DB_SQLITE_DEV));\
    $(call log,header2,DB format,$$DB_FORMAT);\
	DBREF=sqlite:///$(DB_SQLITE_DEV);\
    DB_VERSION=$$(python ./sa_migrate/$(REPO)/manage.py db_version );\
    $(call log,header2,DB schema version,$$DB_VERSION);

#    [ -e manage.py ] || migrate manage manage.py --repository=$(REPO) --url=$$DBREF


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

symlinks: $/.symlinks
	@\
    $(call log,header1,$@,Symlinking from,$^);\
    SCRIPT_MPE=/srv/project-mpe/script-mpe ./init-symlinks.sh .symlinks


INSTALL += symlinks

#      ------------ --
#
include                $(MK_SHARE)Core/Main.dirstack-pop.mk
# vim:noet:
