# Script output is 'E1' if params are 'b', and empty for all other values.
case "${*:?}" in

    a ) true ;;
    b ) false ;;

esac || echo E$?
