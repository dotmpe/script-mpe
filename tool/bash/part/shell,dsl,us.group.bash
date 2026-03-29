us_dsl_shell_pre=User-Script.Shell
us_dsl_shell_grp=( us-arr )

declare -gA \
us_dsl_shell_als=(

  [_Sh_ByName_Add]=.byname-add-unique
  [_Sh_ByName_Concat_After]=.byname-concat-after
  [_Sh_ByName_Set]=.byname-set-value
  [_Sh_Fun_Body]=.function-body
  [_Sh_Fun_Eval]=.function-eval
  [_Sh_Fun_Exists]=.function-exists
  [_Sh_Maptabvars_Defaults]=.maptabvars-defaults
  [_Sh_Mapvars_Defaults]=.mapvars-defaults
  [_Sh_Reload_Source]=.reload-source
  [_Sh_Static_Expand]=.expand-static
  [_Sh_Try_Unalias]=.try-unalias

  [_Sys_Arr_Union]=User-Script.Array.union
  [_Sys_Arr_Find]=User-Script.Array.find
)

declare -gA \
us_dsl_shell_ssc=(

  [:pass]=return
)
#
