#!/system/bin/sh
# Author: Cirrest

MODDIR=${0%/*}
RUNTIME_DIR=/data/adb/md_ph_001_dolby_atmos
DONOR_ROOT="$MODDIR/payload/vendor"
STATE_FILE="$RUNTIME_DIR/service.state"
STAGE_FILE="$MODDIR/config/stage.conf"
DMS_INSTANCE='vendor.dolby.hardware.dms@2.0::IDms/default'
CODEC_INSTANCE='android.hardware.media.c2@1.0::IComponentStore/default1'
DMS_BINARY="$DONOR_ROOT/bin/hw/vendor.dolby.hardware.dms@2.0-service"
CODEC_BINARY="$DONOR_ROOT/bin/hw/vendor.dolby.media.c2@1.0-service"
AUDIO_RESTART_REQUEST=/data/user/0/com.cirrest.dolbycontrol.mdph001/files/restart_audio_service.request
DDP_LIBRARY="$DONOR_ROOT/lib64/libcodec2_soft_ddpdec.so"
JOC_EVENT_SHIM="$MODDIR/system/vendor/lib64/libcirrest_joc_event.so"
EXPECTED_DDP_SHA256=da60ff046d7c2d891c14235b24dc7d6122954489cdc64ff5e811e072763b0d1c
JOC_EVENT_PROPERTY=debug.cirrest.dolby.joc
JOC_EVENT_CLEAR=2:0:0:0:0:0
JOC_EVENT_STATE="$RUNTIME_DIR/joc-event.state"

write_state() {
    /system/bin/printf '%s\n' "$1" > "$STATE_FILE"
}

clear_joc_event() {
    /system/bin/setprop "$JOC_EVENT_PROPERTY" "$JOC_EVENT_CLEAR" 2>/dev/null
}

stop_process() {
    name=$1
    pid_file="$RUNTIME_DIR/$name.pid"
    [ -f "$pid_file" ] || return 0
    pid=$(/system/bin/cat "$pid_file" 2>/dev/null)
    case "$pid" in
        ''|*[!0-9]*) ;;
        *) /system/bin/kill "$pid" 2>/dev/null ;;
    esac
    /system/bin/rm -f "$pid_file"
}

start_process() {
    name=$1
    binary=$2
    if [ ! -x "$binary" ]; then
        write_state "${name}_binary_missing"
        return 1
    fi
    LD_LIBRARY_PATH="$DONOR_ROOT/lib64:/vendor/lib64:/system/lib64" \
        "$binary" >> "$RUNTIME_DIR/$name.log" 2>&1 &
    pid=$!
    /system/bin/printf '%s\n' "$pid" > "$RUNTIME_DIR/$name.pid"
}

start_codec_process() {
    if [ ! -x "$CODEC_BINARY" ]; then
        write_state codec_binary_missing
        return 1
    fi
    clear_joc_event
    actual_sha=$(/system/bin/sha256sum "$DDP_LIBRARY" 2>/dev/null)
    actual_sha=${actual_sha%% *}
    if [ "$actual_sha" = "$EXPECTED_DDP_SHA256" ] && [ -r "$JOC_EVENT_SHIM" ]; then
        /system/bin/printf '%s\n' enabled > "$JOC_EVENT_STATE"
        LD_PRELOAD="$JOC_EVENT_SHIM" \
        LD_LIBRARY_PATH="$DONOR_ROOT/lib64:/vendor/lib64:/system/lib64" \
            "$CODEC_BINARY" >> "$RUNTIME_DIR/codec.log" 2>&1 &
    else
        /system/bin/printf '%s\n' unsupported_identity > "$JOC_EVENT_STATE"
        LD_LIBRARY_PATH="$DONOR_ROOT/lib64:/vendor/lib64:/system/lib64" \
            "$CODEC_BINARY" >> "$RUNTIME_DIR/codec.log" 2>&1 &
    fi
    pid=$!
    /system/bin/printf '%s\n' "$pid" > "$RUNTIME_DIR/codec.pid"
}

wait_for_hwservicemanager() {
    /system/bin/timeout 30 /system/bin/sh -c '
        while [ "$(/system/bin/getprop init.svc.hwservicemanager)" != "running" ]; do
            /system/bin/sleep 1
        done
    '
}

wait_for_boot_completed() {
    /system/bin/timeout 300 /system/bin/sh -c '
        while [ "$(/system/bin/getprop sys.boot_completed)" != "1" ]; do
            /system/bin/sleep 1
        done
    '
}

wait_for_hwservice() {
    instance=$1
    /system/bin/timeout 30 /system/bin/sh -c '
        instance=$1
        while ! /system/bin/lshal -ti 2>/dev/null | /system/bin/grep -F -q "$instance"; do
            /system/bin/sleep 1
        done
    ' mdph-atmos-wait "$instance"
}

wait_for_audioserver_restart() {
    previous_pid=$1
    /system/bin/timeout 30 /system/bin/sh -c '
        previous_pid=$1
        while true; do
            current_pid=$(/system/bin/pidof audioserver 2>/dev/null)
            state=$(/system/bin/getprop init.svc.audioserver)
            if [ -n "$current_pid" ] && [ "$current_pid" != "$previous_pid" ] && [ "$state" = "running" ]; then
                exit 0
            fi
            /system/bin/sleep 1
        done
    ' mdph-atmos-audioserver "$previous_pid"
}

/system/bin/mkdir -p "$RUNTIME_DIR"
/system/bin/chmod 0700 "$RUNTIME_DIR"
trap 'clear_joc_event' 0 1 2 15

stage=codec-only
if [ -f "$STAGE_FILE" ]; then
    . "$STAGE_FILE"
fi
case "$stage" in
    codec-only|codec+dap|release) ;;
    *) write_state stage_invalid; exit 1 ;;
esac

if ! wait_for_hwservicemanager; then
    write_state hwservicemanager_failed
    exit 1
fi

if ! start_codec_process; then
    exit 1
fi
if ! wait_for_hwservice "$CODEC_INSTANCE"; then
    write_state codec_failed
    stop_process codec
    exit 1
fi

if [ "$stage" != "codec-only" ]; then
    if ! wait_for_boot_completed; then
        write_state boot_timeout
        stop_process codec
        exit 1
    fi
    if ! start_process dms "$DMS_BINARY"; then
        stop_process codec
        exit 1
    fi
    if ! wait_for_hwservice "$DMS_INSTANCE"; then
        write_state dms_failed
        stop_process dms
        stop_process codec
        exit 1
    fi
fi

ready_state="${stage}_ready"
write_state "$ready_state"

while true; do
    codec_pid=$(/system/bin/cat "$RUNTIME_DIR/codec.pid" 2>/dev/null)
    if [ -z "$codec_pid" ] || ! /system/bin/kill -0 "$codec_pid" 2>/dev/null; then
        clear_joc_event
        write_state codec_exited
        stop_process dms
        exit 1
    fi
    if [ -f "$AUDIO_RESTART_REQUEST" ]; then
        previous_pid=$(/system/bin/pidof audioserver 2>/dev/null)
        /system/bin/rm -f "$AUDIO_RESTART_REQUEST"
        write_state audio_restart_requested
        /system/bin/setprop ctl.restart audioserver
        if wait_for_audioserver_restart "$previous_pid"; then
            write_state "$ready_state"
        else
            write_state audio_restart_failed
        fi
    fi
    /system/bin/sleep 1
done
