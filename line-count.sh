# Count actual lines of files from find inv

sh_mode strict dev
lib_require os sys

test $# -gt 0 || set -- . -type f

if_ok "$(find "$@")" &&
  <<< "$_" mapfile -t files &&
  for file in "${files[@]}"
  do
    if_ok "$(read_nix_style_file "$file" | count_lines)" &&
      printf '%s\t%s\n' "$_" "$file"
  done | awk '{
    print i" +"$1
    i+=$1
  }
  END { print i }'

#
