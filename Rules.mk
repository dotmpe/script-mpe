# Non recursive make, partial rule file. See github mkdocs.
include                $(MK_SHARE)Core/Main.dirstack.mk
MK                  += $/Rules.mk
#
#      ------------ -- 

STRGT               += test_py_$d test_sa_$d

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

test_py_$d::
	@$(call log_line,info,$@,Starting python unittests..)
	@\
		PYTHONPATH=$$PYTHONPATH:./;\
		PATH=$$PATH:~/bin;\
		TEST_PY=test.py;\
		TEST_LIB=confparse,confparse2,taxus,rsr,radical,workLog;\
		VERBOSE=2;\
    $(test-python) 2> test.log
	@if [ -n "$$(tail -1 test.log|grep OK)" ]; then \
	    $(ll) Success "$@" "see" test.log; \
    else \
	    $(ll) Errors "$@" "$$(tail -1 test.log)"; \
	    $(ll) Errors "$@" see test.log; \
    fi

test_sa_$d::
	@$(call log_line,info,$@,Testing SQLAlchemy repository..);
	@\
	DBREF=sqlite:///$(DB_SQLITE_TEST);\
	sqlite3 $(DB_SQLITE_TEST) ".q"; \
	python $D$(REPO)/manage.py test --repository=$(REPO) --url=$$DBREF

sa-upgrade::
	./manage.py upgrade

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
