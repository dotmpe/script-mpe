###	SQL Alchemy repository schema control
#
#	  ------------ -- 

R ?= cllct
REPO = $(R)
#ALL_REPOS=cllct test

sa-list::
	for m in ./sa_migrate/*/manage.py ; do $$m dbpath ; done

sa-create::
	test ! -d ./sa_migrate/$(REPO)
	@$(ll) attention $@ Starting...
	@\
	migrate create ./sa_migrate/$(REPO) $(REPO);\
	cp ./sa_migrate/_manage_boilerplate.py ./sa_migrate/$(REPO)/manage.py;\
	chmod +x ./sa_migrate/$(REPO)/manage.py;\
	{ echo ""; echo "[mpe]"; echo "path = $$(realpath .cllct/$(REPO).sqlite)";\
	} >> ./sa_migrate/$(REPO)/migrate.cfg ;\
	./sa_migrate/$(REPO)/manage.py dbpath
	@ls -la $$(./sa_migrate/$(REPO)/manage.py dbpath)
	@$(ll) info $@ Done

sa-touch::
	@$(ll) attention $@ Starting...
	@\
	dbpath=$$( ./sa_migrate/$(REPO)/manage.py dbpath );\
	mkdir -p $$(dirname $$dbpath);\
	echo ".databases" | sqlite3 $$dbpath >/dev/null

#sa:: T :=
sa::
	@./sa_migrate/$(REPO)/manage.py $(T)

session::
	@\
	dbpath=$$( ./sa_migrate/$(REPO)/manage.py dbpath );\
	sqlite3 $$dbpath


sa-vc:: T := version_control
sa-vc:: sa

sa-latest:: T := upgrade
sa-latest:: sa

# Show DB schema
sa-schema::
	@DB_PATH=$$(./sa_migrate/$(REPO)/manage.py dbpath);\
	    echo .schema | sqlite3 $$DB_PATH

# Compare model to DB schema
#sa-compare:: T := compare_model_to_db script_mpe.taxus.init:SqlBase.metadata
sa-compare:: T := compare_model_to_db script_mpe.sa_migrate.$(REPO).model.meta
sa-compare:: sa

# XXX: create up-script
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

#	[ -e manage.py ] || migrate manage manage.py --repository=$(REPO) --url=$$DBREF
