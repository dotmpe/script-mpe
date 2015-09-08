# Id: script.mpe/0.0.0+20150908-1716 Rules.mk
#
# Non recursive make, partial rule file. See github mkdocs.
include                $(MK_SHARE)Core/Main.dirstack.mk
MK                  += $/Rules.mk
#
#      ------------ -- 


VERSION= 0.0.0+20150908-1716# script.mpe

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

ifeq ($(shell hostname -s),simza)
TEST_$d             := test_match_$d test_htd_$d test_other_bats_$d
#test_usr_$d 
#test_sa_$d test_schema_$d test_py_$d 
else
TEST_$d             := test_match_$d test_htd_$d test_other_bats_$d
endif

STRGT               += $(TEST_$d)

TRGT += libcmdng.html

libcmdng.html: libcmdng.py
	@$(ll) file_target "$@" "Generating docs for" "$<"
	@\
	pydoc -w ./$^
	@$(ll) file_ok "$@"

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
test_usr_$d:: TESTS:= 
test_usr_$d::
	@$(ll) info $@ "Starting usr cmd tests.."
	@#python -c 'import sys;print sys.path'
	@-python -c 'import script_mpe;print script_mpe'
	-./myCalendar.py || echo "Status 1=$$? OK"
	-./myCalendar.py -h || echo "Status 1=$$? OK"
	@\
	    LOG=test-system.log;\
        test/system.sh $(TESTS) | tee $$LOG 2>&1 | tee test-system.out ; \
    \
        PASSED=$$(echo $$(grep PASSED $$LOG | wc -l)); \
        FAILED=$$(echo $$(grep FAILED $$LOG | wc -l)); \
        [ $$FAILED -gt 0 ] && { \
            $(ll) error "$@" "$$FAILED failures, see" $$LOG; \
        } || { \
            $(ll) Ok "$@" "$$PASSED passed" $$LOG; \
        }

test_match_$d::
test_match_$d::
	source ~/bin/htd && match_load \
	    && match_name_pattern ./@NAMEPARTS.@SHA1_CKS@PART.@EXT PART \
	    && echo $$grep_pattern
	source ~/bin/htd && match_load \
	    && match_name_pattern_opts ./@NAMEPARTS.@SHA1_CKS@PART.@EXT PART
	-./match.sh || echo "Status 1=$$? OK"
	bats ./test/match-spec.bats

test_htd_$d::
test_htd_$d::
	# TODO convert these to bats
	@#htd check-names 256colors2.pl
	@#MIN_SIZE=5120 htd ck-update ck *.py > /dev/null 2> /dev/null
	@#MIN_SIZE=4096 htd ck-update sha1 *.py > /dev/null 2> /dev/null
	@#htd ck-validate > /dev/null 2> /dev/null
	@#htd ck-validate sha1 > /dev/null 2> /dev/null
	bats ./test/htd-spec.bats

test_other_bats_$d::
	bats ./test/{basename-reg,box,box.lib,helper,main,mimereg,str,util-lib,dckr}-spec.bats

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


test_schema_$d:
	@$(ll) attentino $@ "Testing validator with jsonschema, hyper-schema and links schemas..."
	@jsonschema -i schema/hyper-schema.json schema/jsonschema.json
	@jsonschema -i schema/hyper-schema.json schema/hyper-schema.json
	@jsonschema -i schema/links.json schema/hyper-schema.json
	@$(ll) file_warning taxus.schema.json "now writing JSON schema for" taxus-schema.yml
	@yaml2json taxus-schema.yml > taxus-schema.json
	@$(ll) OK $@ "now validating Taxus schema..."
	@jsonschema -i taxus-schema.json schema/jsonschema.json
	@$(ll) file_warning schema_test.json "now writing JSON schema for" schema_test.yml
	@yaml2json schema_test.yml > schema_test.json
	@$(ll) OK $@ "now validating schema_test..."
	@jsonschema -i schema_test.json taxus-schema.json
	@$(ll) file_warning schema/base.json "now writing JSON schema for" schema/base.yml
	@yaml2json schema/base.yml > schema/base.json
	@$(ll) OK $@ "now validating schema/base..."
	@jsonschema schema/base.json

###    SQL Alchemy repository schema control
#
#      ------------ -- 

R ?= cllct
REPO = $(R)
#ALL_REPOS=cllct test

sa-create::
	@$(ll) attention $@ Starting...
	@\
	migrate create ./sa_migrate/$(REPO) $(REPO);\
	tree ./sa_migrate/$(REPO)/;
	@$(ll) info $@ Done

sa-touch::
	@$(ll) attention $@ Starting...
	@\
	dbpath=$$( ./sa_migrate/$(REPO)/manage.py dbpath );\
	mkdir -p $$(dirname $$dbpath);\
	echo "" | sqlite3 -batch $$dbpath

#sa:: T :=
sa::
	@\
	./sa_migrate/$(REPO)/manage.py $(T)

session::
	@\
	dbpath=$$( ./sa_migrate/$(REPO)/manage.py dbpath );\
	sqlite3 $$dbpath

sa-vc:: T := version_control
sa-vc:: sa

sa-latest:: T := upgrade
sa-latest:: sa

sa-compare:: T := compare_model_to_db taxus.core:SqlBase.metadata
sa-compare:: sa

sa-reset:: T := reset
sa-reset:: sa
	@ls -la $$(./sa_migrate/$(REPO)/manage.py dbpath)

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

IGNORE := coverage_html_report ReadMe.rst Rules.mk '*.html' '*.xml' TODO.list
IGNORE_F := $(addprefix --exclude ,$(IGNORE))
todo: TODO.list
TODO.list: $/
	@\
		$(ll) file_target $@ "Grepping for" $<;\
		grep -srI $(IGNORE_F) 'FIXME' $< > $@;\
		echo >> $@;\
		grep -srI $(IGNORE_F) 'TODO' $< >> $@;\
		echo >> $@;\
		grep -srI $(IGNORE_F) 'XXX' $< >> $@
	@#radical.py -vvvvv > $@
	@$(ll) file_ok $@ 


INSTALL += symlinks

#      ------------ --
#
include                $(MK_SHARE)Core/Main.dirstack-pop.mk
# vim:noet:
