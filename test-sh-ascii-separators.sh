
### Using ASCI separator characters to make 4-level nested list data structure

set -euo pipefail

## ASCII chars

# Unit Separator
US=$'\037'
# Record Separator
RS=$'\036'
# Group Separator
GS=$'\035'
# File Separator
FS=$'\034'

read_unit_at_index ()
{
  read_sep=$'\037' read_at_index unit "${1:?}"
}

read_record_at_index ()
{
  read_sep=$'\036' read_at_index record "${1:?}"
}

read_group_at_index ()
{
  read_sep=$'\035' read_at_index group "${1:?}"
}

read_file_at_index ()
{
  read_sep=$'\034' read_at_index file "${1:?}"
}

read_at_index ()
{
  local var=${1:?}
  shift
  while test ${1:?} -gt 0
  do
    IFS= read -d ${read_sep:?} $var || return
    set -- $(( $1 - 1 ))
  done
}

read_data_at_index ()
{
  local file group record unit

  read_file_at_index "${1:?}" || return
  test $# -gt 1 || {
    echo "$file"
    return
  }

  read_group_at_index "${2:?}" <<< "$file"
  test $# -gt 2 || {
    echo "$group"
    return
  }

  read_record_at_index "${3:?}" <<< "$group"
  test $# -gt 3 || {
    echo "$record"
    return
  }

  read_unit_at_index "${4:?}" <<< "$record"
  echo "$unit"
}

data=$(for f in $(printf 'file%s\n' $(seq 1 3))
do
    printf '%s'"$FS" $(
    for g in $(printf "$f:"'group%s\n' $(seq 1 3))
    do
        printf '%s'"$GS" $(
        for r in $(printf "$g:"'record%s\n' $(seq 1 3))
        do
            printf '%s'"$RS" $(
                printf '%s'"$US" $(printf "$r:"'unit%s\n' $(seq 1 3))
            )
        done)
    done)
done)


# Read first file
#read_data_at_index 1 <<< "$data"
# Read first record from first file
#read_data_at_index 1 1 <<< "$data"
# Read first group, from first record, of first file
#read_data_at_index 1 1 1 <<< "$data"
# Read first unit, idem.
read_data_at_index 1 1 1 1 <<< "$data"
read_data_at_index 1 2 3 1 <<< "$data"
read_data_at_index 3 2 1 2 <<< "$data"

#
