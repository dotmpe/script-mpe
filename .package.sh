package_vendor=dotmpe
package_license=GPL
package_environments__0=development
package_pd_meta_test=":vchk :-sh:python:test/main.py :bats:specs :bats"
package_pd_meta_git_hooks_pre_commit=./tools/git-hooks/pre-commit.sh
package_pd_meta_init="./install-dependencies.sh git:init"
package_pd_meta_check=":vchk :bats:specs"
package_environment_development__0=package_pd_meta_default=dev
package_environment_development__1=Build_Deps_Default_Paths=1
package_environment_development__2=BOREAS_SKIP=1
package_environment_development__3=DANDY_SKIP=1
package_environment_development__4=VS1_SKIP=1
package_version=0.0.0-dev
package_distribution=public
package_main=script-mpe
package_type=application/x-project-mpe
package_id=script-mpe
