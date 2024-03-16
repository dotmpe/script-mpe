sh_mode strict dev build
lib_require args std-uc lib-uc class-uc uc-class
lib_init
class_init Std_Rules
class_new runner Std_Rules
$runner${1:-:run} test/index.list
