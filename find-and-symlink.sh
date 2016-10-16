DIR=$1
PATTERN=$2

if test -z "$PATTERN";
then
    PATTERN='*.rst'

EDIR=$(echo $DIR|sed -e 's/[\/\.]/\\$1/g')

find ~/project/docutils-ext.git/ -iname $PATTERN \
    | while read f \
    do 
        F=${f//\/home\/berend\/project\/docutils-ext.git\//}; \
        PATHDIFF=$(echo $(dirname $F) | \
            sed -e 's/[\.].*//g' - | \
            sed -e 's/[a-z0-9\.-]\+\/\?/\.\.\//g' -); \
        \
        echo ln -s ../../../${PATHDIFF}project/docutils-ext.git/$F $F; done

