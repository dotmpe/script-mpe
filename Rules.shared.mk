
#
# Manage CI setup from mkdoc installation.
# See .travis for CI core scripts. 
#

STRGT += init check check-env install_$d build_$d \
				 ci-list ci-test
DEP += check-env
INSTALL += install_$d
TRGT += build_$d

init:
	@\
		SCR_SYS_SH=bash-sh; \
		scriptname=tools:init; \
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
		. $$scriptdir/tools/ci/parts/init.sh

install_$d:
	@\
		SCR_SYS_SH=bash-sh; \
		scriptname=tools:install; \
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
		. $$scriptdir/tools/ci/parts/install.sh

build_$d:
	@\
		SCR_SYS_SH=bash-sh; \
		scriptname=tools:build; \
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
		. $$scriptdir/tools/ci/parts/build.sh

check-env:
	@\
		SCR_SYS_SH=bash-sh; \
		scriptname=tools:check-env; \
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
		. $$scriptdir/tools/ci/check-env.sh

check:
	@\
		SCR_SYS_SH=bash-sh; \
		scriptname=tools:check; \
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
		$$TEST_SHELL . $$scriptdir/tools/ci/parts/check.sh


# check/list build envs for job(s)
ci-list: ENV := development
ci-list:
	@\
		SCR_SYS_SH=bash-sh; \
		scriptdir="$$(pwd -P)"; \
		. ./tools/sh/list.sh $(ENV)

# run job(s)
ci-test: ENV := development
ci-test:
	@\
		SCR_SYS_SH=bash-sh; \
		scriptdir="$$(pwd -P)"; \
		. ./tools/sh/run.sh $(ENV)


