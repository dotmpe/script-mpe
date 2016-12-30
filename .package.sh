
package_data_finfo_handlers__0="last_updated:mtime"
package_data_finfo_handlers__1="last_seen:atime"
package_data_finfo_handlers__2="mime_type:lib..."
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
package_pd_meta_check="sh:verbose=false:max=385:./tools/sh/tags.sh htd:gitflow-check-doc :verbose=1:vchk :bats:specs ./bin/behat:--dry-run:--no-multiline :git:status"
package_pd_meta_git_hooks_pre_commit=./tools/git-hooks/pre-commit.sh
package_pd_meta_init="./install-dependencies.sh git:init"
package_pd_meta_run_behat="./bin/behat:--tags:~@skip"
package_pd_meta_run_behat_defs="./bin/behat:-dl"
package_pd_meta_run_behat_specs="./bin/behat:--dry-run:--no-multiline:--no-expand:--tags:~@todo&&~@skip"
package_pd_meta_tasks_document=tasks.ttxtm
package_pd_meta_tasks_tags__0=TODO
package_pd_meta_tasks_tags__1=XXX
package_pd_meta_tasks_tags__2=FIXME
package_pd_meta_tasks_tags__3=BUG
package_pd_meta_tasks_tags__4=NOTE
package_pd_meta_test=":vchk sh:python:test/main.py :bats:specs :bats :bats:test/ubuntu-suite.bats ./bin/behat:--tags:~@skip"
package_type=application/vnd.dotmpe.project
package_vendor=dotmpe
package_version=0.0.3-dev
