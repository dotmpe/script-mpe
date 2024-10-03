# Redis seems most favorable at Boreas

count=10
#cmd="htd version"
cmd="htd git-status"
#cmd="git status"

echo Direct
time ( for x in $(seq 0 $count)
do
  $cmd
done 2>&1 >/dev/null )


echo
echo Redis
redis-cli set git "$($cmd)"
time ( for x in $(seq 0 $count)
do
  redis-cli get git
done 2>&1 >/dev/null )


echo
echo Memcache

membash set git 60 "$($cmd)"

time ( for x in $(seq 0 $count)
do
  membash get git
done 2>&1 >/dev/null )


#echo
#printf "Direct: $($cmdatus)\n\n"
#printf "Redis: $(redis-cli get git)\n\n"
#printf "Memcached: $(membash get git)\n\n"

#
