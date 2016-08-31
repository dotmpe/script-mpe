
package_distribution=public
package_environment_development__0=package_pd_meta_default=dev
package_environment_development__1=Build_Deps_Default_Paths=1
package_environment_development__2=BOREAS_SKIP=1
package_environment_development__3=DANDY_SKIP=1
package_environment_development__4=VS1_SKIP=1
package_environments__0=development
package_id=script-mpe
package_license=GPL
package_main=script-mpe
package_pd_meta_build=":vagrant:tools/ci/vbox"
package_pd_meta_check="-verbose=false:./tools/sh/tags.sh :vchk :bats:specs :git:status"
package_pd_meta_git_hooks_pre_commit=./tools/git-hooks/pre-commit.sh
package_pd_meta_init="./install-dependencies.sh git:init"
package_pd_meta_tasks_tags__0=TODO
package_pd_meta_tasks_tags__1=XXX
package_pd_meta_tasks_tags__2=FIXME
package_pd_meta_tasks_tags__3=BUG
package_pd_meta_tasks_tags__4=NOTE
package_pd_meta_test=":vchk sh:python:test/main.py :bats:specs :bats :bats:test/ubuntu-suite.bats"
package_type=application/x-project-mpe
package_vendor=dotmpe
package_version=0.0.0-dev
