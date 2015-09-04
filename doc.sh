
c_find_doc()
{
  dir=$(dirname $1)
  test "." = "$dir" && {
    dir=$1
    name=$2
    shift 2
  } || {
    name=$(basename $1) # | tr 'A-Z' 'a-z')
    shift 1
  }
}

