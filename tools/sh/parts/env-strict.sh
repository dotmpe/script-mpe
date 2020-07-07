case "$SHELL" in

    */bin/bash )

            # Sh-mode Bash or regular Bash?
            type shopt >/dev/null 2>&1 && sh_mode=0 || sh_mode=1

            $LOG debug "" "Detected Bash" "sh-mode:$sh_mode"
            test $sh_mode -eq 1 &&
                set -eu ||
                set -euo pipefail
        ;;

    */bin/sh )
            set -e
        ;;

    * ) $LOG error "" "Unknown shell" "$SHELL"
        ;;
esac

# Sync: U-S:
