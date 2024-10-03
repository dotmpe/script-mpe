
### Getting tab-delimited fields

# XXX: relatively much of the time is probably spend setting up and doing IO
# should load and keep data as string probably?

# As expected AWK is fairly slow.

test_awk ()
{
  awk '{print $1}'
}

test_cut ()
{
  cut -d $'\t' -f 1
}

test_data ()
{
  echo -e "field 1\tfield 2\tfield 3"
}

source tools/benchmark/_lib.sh

time run_test_io test_ 1000 awk
#time run_test_io test_ 1000 cut

#
