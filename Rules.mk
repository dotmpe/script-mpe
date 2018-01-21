# Id: script-mpe/0.0.4-dev Rules.mk
#
# Non recursive make, partial rule file. See github mkdocs.
include                $(MK_SHARE)Core/Main.dirstack.mk
MK                  += $/Rules.mk
#
#      ------------ -- 


VERSION = 0.0.4-dev# script-mpe

$(eval $(shell [ -d $/.build ] || mkdir $/.build ))

#      ------------ -- 

# XXX Keep long list of clean targets out of normal stat messages
ifneq ($(call contains,$(MAKECMDGOALS),clean),)
CLN                 += .test
CLN                 += $(shell find ./ -iname '*.pyc')
CLN                 += $(shell find ./ -iname '*.log')
CLN                 += $(shell find ./ -iname '.coverage' -o -iname '.coverage-*')
endif


# RDF schemas in notation3 format
#
SCHEMAS_RDF := rdf owl rdfs dcam dc foaf skos

RDF_CONV_N3_CURL := curl -sSf http://rdf-translator.appspot.com/convert/detect/n3/
get_cdn_url = $(shell . .cdn.sh && printf -- "$$$2_$1")

define fetch-n3
	URL="$(call get_cdn_url,n3_http_packages,$(shell basename $@ .n3))"; \
	test -n "$$URL" || exit 1
endef
define convert-n3
	URL="$(call get_cdn_url,rdfxml_http_packages,$(shell basename $@ .n3))"; \
	test -n "$$URL" || exit 1; \
	$(RDF_CONV_N3_CURL)$$URL | sed 's/\<'$(shell basename $@)':/:/g' >$@
endef
define get-n3
	$(fetch-n3) && exit 0 || true; \
	$(convert-n3)
endef

schema/%.n3:
	@$(get-n3)

DEP += $(addprefix schema/,$(addsuffix .n3,$(SCHEMAS_RDF)))

DEP += $/.cdn.sh

$/.cdn.sh: $/cdn.yml
	jsotk dump -Iyml -Ofkv $^ > $@


###    Test targets
#
#      ------------ -- 


ifeq ($(shell hostname -s),simza)
TEST_$d             := test_match_$d test_htd_$d test_other_bats_$d 
#test_usr_$d 
#test_sa_$d test_schema_$d test_py_$d 
else
TEST_$d             := test_match_$d test_htd_$d test_other_bats_$d test-ci
endif

STRGT               += $(TEST_$d)

TRGT += libcmdng.html

$Bpydoc/%.html: $/%.py
	@$(ll) file_target "$@" "Generating pydoc for" "$<"
	@pydoc -w ./$^
	@$(ll) file_ok "$@"

test:: $(TEST_$d)

test-ci::
	. ./tools/sh/env.sh; \
	. ./tools/ci/test.sh

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
	scriptname=make:$@ ; \
	. ~/bin/{util,{match,{,.lib}}}.sh && . ~/bin/match.lib.sh && match_load
	scriptname=make:$@ ; \
	. ~/bin/{util,{match,{,.lib}}}.sh && . ~/bin/match.lib.sh && match_load \
	    && match_name_pattern ./@NAMEPARTS.@SHA1_CKS@PART.@EXT PART \
	    && echo $$grep_pattern
	scriptname=make:$@ ; \
	. ~/bin/{util,{match,{,.lib}}}.sh && . ~/bin/match.lib.sh && match_load \
	    && match_name_pattern_opts ./@NAMEPARTS.@SHA1_CKS@PART.@EXT PART
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
	@failed=/tmp/$@.failed; test ! -e $$failed || rm $$failed; \
	$(shell hostname -s | tr 'a-z' 'A-Z')_SKIP=1; \
	for x in ./test/{basename-reg,box,box.lib,helper,main,mimereg,str,util-lib,dckr}-spec.bats; \
	do \
		echo Running Bats spec: $$x;bats $$x || echo $$x>>$$failed; \
	done; \
	test ! -e $$failed || { echo Failed specs in files:; cat $$failed; rm $$failed; exit 1; }


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


DEP += $(BUILD)pd-make-states.sh
# FIXME:	$(MK) has non-existing targets
$(BUILD)pd-make-states.sh: $(SRC) Rules.mk
	@{ \
		echo sources=$$(echo $$(echo $(SRC) | wc -w)); \
		echo dep=$$(echo $$(echo $(DEP) | wc -w)); \
		echo dmk=$$(echo $$(echo $(DMK) | wc -w)); \
		echo targets=$$(echo $$(echo $(TRGT) | wc -w)); \
		echo special-targets=$$(echo $$(echo $(STRGT) | wc -w)); \
		echo cleanable=$$(echo $$(echo $(CLN) | wc -w)); \
		echo tests=$$(echo $$(echo $(TESTS) | wc -w)); \
		echo src/mk/loc=$$(pd loc *.mk); \
		echo src/py/loc=$$(pd loc *.py */*.py */*/*.py */*/*/*.py); \
		echo src/sh/loc=$$(pd loc *.sh); \
		echo src/sh/main/loc=$$(pd loc main*.*); \
		echo src/sh/lib/loc=$$(pd loc *.lib.sh); \
		echo src/sh/match/loc=$$(pd loc match*.sh); \
		echo src/sh/disk/loc=$$(pd loc disk*.sh); \
		echo src/sh/graphviz/loc=$$(pd loc graphviz*.sh); \
		echo src/sh/vc/loc=$$(pd loc vc*.sh); \
		echo src/sh/statusdir/loc=$$(pd loc statusdir*.sh); \
		echo src/sh/htd/loc=$$(pd loc htd htd.lib.sh); \
		echo src/sh/pd/loc=$$(pd loc projectdir*.sh); \
		echo src/sh/bats-specs/loc=$$(pd loc test/*-spec.bats); \
		echo doc/rst/loc=$$(pd loc *.rst); \
	} \
		> $@


TRGT += TODO.list

todo: TODO.list
TODO.list: $/
	@Check_All_Tags=1 Check_All_Files=1 ./tools/sh/tags.sh > $@
	@echo "# tasks-ignore-file" >> $@
	@#radical.py -vvvvv > $@
	@$(ll) file_ok $@ 


INSTALL += symlinks


.versioned-files.list::
	git grep -l '^__version__\ =\ .* script-mpe' | while read py ;\
	do \
		grep -qF "$$py" $@ || { \
			echo "Adding $$py to $@" >&2 ; echo "$$py" ; \
		} ; \
	done >> $@

DEP += .versioned-files.list

#      ------------ --
#
include                $(MK_SHARE)Core/Main.dirstack-pop.mk
# vim:noet:
