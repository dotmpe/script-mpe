sh_mode strict dev # XXX: build
lib_load user-script
user_script_initlog
uc_script_load user-script
lib_require args std-uc shell-uc lib-uc class-uc uc-class
lib_init
class_init Std/Rules
class_new runner Std/Rules

${runner:?}.load-file "${2:-test/index.list}"

${runner:?}${1:-:run-all}
