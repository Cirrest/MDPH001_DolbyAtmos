#!/system/bin/sh
# Author: Cirrest

MODDIR=${0%/*}
RUNTIME_DIR=/data/adb/md_ph_001_dolby_atmos

model=$(/system/bin/getprop ro.product.model)
release=$(/system/bin/getprop ro.build.version.release)
case "$model" in
    MD_PH_001|MD-PH-001) ;;
    *) exit 1 ;;
esac
[ "$release" = "14" ] || exit 1

/system/bin/mkdir -p "$RUNTIME_DIR"
/system/bin/chmod 0700 "$RUNTIME_DIR"
/system/bin/rm -f /data/vendor/audiohal/cirrest-effects.ready
for executable in \
    "$MODDIR/system/vendor/bin/hw/android.hardware.audio.service.mediatek" \
    "$MODDIR/system/vendor/bin/hw/cirrest-audio-hal-real" \
    "$MODDIR/system/vendor/bin/hw/cirrest-effects-factory" \
    "$MODDIR/system/vendor/bin/hw/cirrest-dlopen-probe"; do
    [ -f "$executable" ] || continue
    /system/bin/chcon u:object_r:mtk_hal_audio_exec:s0 "$executable" || exit 1
done
system_library="$MODDIR/system/lib64/libaudiohal@7.0.so"
if [ -f "$system_library" ]; then
    /system/bin/chcon u:object_r:system_lib_file:s0 "$system_library" || exit 1
fi
for library in \
    "$MODDIR/system/vendor/lib/libcirrest_audio_hook.so" \
    "$MODDIR/system/vendor/lib64/soundfx/libswdap.so" \
    "$MODDIR/system/vendor/lib64/soundfx/libhwdap.so" \
    "$MODDIR/system/vendor/lib64/soundfx/libswspatializer.so" \
    "$MODDIR/system/vendor/lib64/soundfx/libaudiohalutils.so" \
    "$MODDIR/system/vendor/lib64/libdapparamstorage.so" \
    "$MODDIR/system/vendor/lib64/libdlbpreg.so" \
    "$MODDIR/system/vendor/lib64/libspatializerparamstorage.so" \
    "$MODDIR/system/vendor/lib64/vendor.dolby.hardware.dms@2.0.so"; do
    [ -f "$library" ] || continue
    /system/bin/chcon u:object_r:vendor_file:s0 "$library" || exit 1
done
for config in \
    "$MODDIR/system/vendor/etc/media_codecs.xml" \
    "$MODDIR/system/vendor/etc/media_codecs_c2_dolby_audio.xml" \
    "$MODDIR/system/vendor/etc/audio_effects.xml" \
    "$MODDIR/system/vendor/etc/dolby/dax-default.xml" \
    "$MODDIR/system/vendor/etc/dolby/dax-default-spatializer.xml" \
    "$MODDIR/system/vendor/etc/vintf/manifest/cirrest-dolby-codec2.xml" \
    "$MODDIR/system/vendor/etc/vintf/manifest/cirrest-dolby-dms.xml"; do
    [ -f "$config" ] || continue
    /system/bin/chcon u:object_r:vendor_configs_file:s0 "$config" || exit 1
done
/system/bin/date +%s > "$RUNTIME_DIR/boot_timestamp"
