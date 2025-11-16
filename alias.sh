
ENV_SRC=${ENV_SRC:+$ENV_SRC }${HOME:-~}/bin/alias.sh
ENV_SEQ=${ENV_SEQ:+$ENV_SEQ }alias,sh,user,us
: "${ENV_CTX:=$0[$$]:${HOME:-~}/bin/alias}"

_us_bin_alias_sh=alias.sh

__=~/bin/.alias
test  "${C_INC:?"$0[$$]: ${__}: User includes env expected (required)"}}"

#test    "${U_C:?"$0[$$]: ${__}: User config env expected (required)"}}"
#test  "${UCONF:?"$0[$$]: ${__}: User config env expected (required)"}}"

#test "${US_BIN:?"$0[$$]: ${__}: User scripts env expected (required)"}}"
#test    "${U_S:?"$0[$$]: ${__}: User scripts env expected (required)"}}"


alias htd=htd.sh

# Alias box scripts
alias ht="b=$HOME/bin/ht _shc_update_and_run"
alias statusdir="b=$HOME/bin/statusdir _shc_update_and_run"
test "$(type -t sd)" || alias sd=statusdir # otherwise gives trouble with compo:sd.inc
#alias vc=vc.sh TODO: rename scm
alias vc="b=$HOME/bin/vc _shc_update_and_run"
alias box="b=$HOME/bin/box _shc_update_and_run"
alias box.us=box.us.sh
alias docker-sh="b=$HOME/bin/docker-sh _docker-sh_update_and_run"
alias dckr=docker-sh.sh
alias disk="b=$HOME/bin/disk _shc_update_and_run"
alias ino="b=$HOME/bin/ino _shc_update_and_run"
alias meta-sh="b=$HOME/bin/meta-sh _shc_update_and_run"
for box_bin in "${UCONF:?}"/script/box/bin/*
do
  alias ${box_bin##*\/}="b=$box_bin _shc_update_and_run"
done && unset box_bin

alias topic=topic.py
alias tm=treemap.py
alias lst=list.sh
alias tb=treebox

alias rabo2myLedger=rabo2myLedger.py

#alias basename-reg-old=basename-reg.py

alias disk-usage=disk-usage.sh

alias dictdiff-yaml.php=dictdiff.php
alias finfo-app.py=finfo.py
alias jsotk=jsotk.py
alias libcmd_stacked_test.py=libcmd_test.py
alias pd=projectdir.sh
alias projectdir-meta=pd_meta.py
alias topics=topics.sh
alias vagrant-sh=vagrant-sh.sh

alias yaml2yaml='jsotk dump -Oyaml --ignore-aliases --pretty'

alias yaml2js="python3 -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin, yaml.Loader), sys.stdout, indent=4)'"

# This should perhaps use command timeout. @devtools @shell
# and have more useful features like looping during wait to check for proc
timeout_sh ()
{
  "$@" & pid=$!
  sleep ${TIMEOUT:-2}
  ! ps $pid &&
  echo command already complete || {
    echo timeout reached
    pkill "${1:?}"
  }
}
#TIMEOUT=6; echo -e "item1\nitem2\nitem3\nitem4" | timeout_sh xmenu

test -z "${USER_CONF_DEBUG-}" || {
  $LOG "info" "" "Done sourcing" "~/bin/.alias"
  $LOG "info" :bin:alias "Done sourcing" "~/bin/.alias"
}
