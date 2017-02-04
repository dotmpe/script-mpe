
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
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
    . $$scriptdir/tools/ci/init.sh

install_$d:
	@\
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
    . $$scriptdir/tools/ci/install.sh

build_$d:
	@\
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
    . $$scriptdir/tools/ci/build.sh

check-env:
	@\
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
    . $$scriptdir/tools/ci/check-env.sh

check:
	@\
		. ./tools/sh/init.sh; \
		. $$scriptdir/tools/sh/env.sh; \
    . $$scriptdir/tools/ci/check.sh


# check/list build envs for job
ci-list:
	@\
		scriptdir="$$(pwd -P)"; \
		. ./tools/sh/list.sh $$(ENV)

# run job
ci-test:
	@\
		scriptdir="$$(pwd -P)"; \
		. ./tools/sh/run.sh $$(ENV)


