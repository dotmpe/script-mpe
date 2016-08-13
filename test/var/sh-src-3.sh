
case "$TEST_EXPR" in

    "$MATCH_1_1" | "$MATCH_1_2" )

        case "$TEST_EXPR_1" in

          MATCH_A ) ;;
          MATCH_B ) ;;
          * ) ;;

        esac

      ;;

    "$MATCH_2_1" | "$MATCH_2_2" ) echo 2 ;;

esac;


