# using this as a variable allows easier calling down lower
export GRC='grc -es --colour=auto'

# loop through known commands plus all those with named conf files
for cmd in g++ head ld ping6 tail traceroute6 `locate grc/conf.`; do
  cmd="${cmd##*grc/conf.}"  # we want just the command
  # if the command exists, alias it to pass through grc
  type "$cmd" >/dev/null 2>&1 && alias "$cmd"="$GRC $cmd"
done

# ./configure needs special handling: does it exist and is it executable?
alias configure="[ -x ./configure ] && $GRC ./configure"

# GRC plus LS awesomeness (assumes you have an alias for ls)
#unalias ll 2>/dev/null
if ls -ld --color=always / >/dev/null 2>&1; then GNU_LS=true; fi
function ll() {
  local color= CLICOLOR_FORCE
  if [ -t 1 ] || [ "$CLICOLOR_FORCE" = true ]; then
    if [ -n "$GNU_LS" ]; then color="--color=always"; fi
    CLICOLOR_FORCE=true
  else
    CLICOLOR_FORCE=
  fi
  $GRC `alias ls |awk -F "'" '{print $2}'` -l $color ${1+"$@"}
}


