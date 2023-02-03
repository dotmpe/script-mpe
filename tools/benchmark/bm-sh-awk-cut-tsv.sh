
### Getting tab-delimited fields

# XXX: relatively much of the time is probably spend setting up and doing IO
# should load and keep data as string probably?

# As expected AWK is fairly slow. Maybe want to add tests with choose if I set
# up Rustlang sometime.

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

#
