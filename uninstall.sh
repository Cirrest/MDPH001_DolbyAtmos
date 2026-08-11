#!/system/bin/sh
# Author: Cirrest

RUNTIME_DIR=/data/adb/md_ph_001_dolby_atmos

for name in codec dms; do
    pid_file="$RUNTIME_DIR/$name.pid"
    [ -f "$pid_file" ] || continue
    pid=$(/system/bin/cat "$pid_file" 2>/dev/null)
    case "$pid" in
        ''|*[!0-9]*) ;;
        *) /system/bin/kill "$pid" 2>/dev/null ;;
    esac
done

/system/bin/rm -rf "$RUNTIME_DIR"

