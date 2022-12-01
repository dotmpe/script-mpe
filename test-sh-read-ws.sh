
##

# If we use TAB as field separator with Bash's read, some sort of whitespace
# collapse still happens in case of empty fields. This does not always happen,
# like when using a separator character.

FS=$'\034' # File Separator
FS=$'\035' # Group Separator
FS=$'\036' # Record Separator
FS=$'\037' # Unit Separator

test_data ()
{
  echo "${FS}col2${FS}${FS}col4"
}

test_read="col1 col2 col3 col4"

IFS=$FS read -r $test_read <<< "$(test_data)"
echo "col1='$col1'"
echo "col2='$col2'"
echo "col3='$col3'"
echo "col4='$col4'"
test "$col2" = "col2" || echo 1. E$?

#
