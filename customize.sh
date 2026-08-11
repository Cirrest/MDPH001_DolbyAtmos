#!/system/bin/sh
# Author: Cirrest

ui_print "- 安装前的设备兼容检查"
model=$(getprop ro.product.model)
release=$(getprop ro.build.version.release)
case "$model" in
    MD_PH_001|MD-PH-001) ;;
    *) abort "Unsupported model: $model" ;;
esac
[ "$release" = "14" ] || abort "不受支持的Android版本: $release"
ui_print "设备: $model / Android版本 $release"
ui_print "- ✔设备检查通过，进行安装"

ui_print "- "
ui_print "- 该模块安装以下为MD-PH-001适配的DolbyAtmos服务及依赖"
ui_print "- AC-3, E-AC-3 ， AC-4 音频解码器"
ui_print "- DMS、DXP、DAX服务, DAP控制器、私有NDK库等"
ui_print "- DVL服务会正常注册，但不会自动附加到该音频框架。(省的全局SRC绕过这特色功能没了)"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
[ -d "$MODPATH/payload/vendor/bin" ] && \
    set_perm_recursive "$MODPATH/payload/vendor/bin" 0 2000 0755 0755
[ -f "$MODPATH/system/vendor/bin/hw/android.hardware.audio.service.mediatek" ] && \
    set_perm "$MODPATH/system/vendor/bin/hw/android.hardware.audio.service.mediatek" 0 2000 0755
[ -f "$MODPATH/system/vendor/bin/hw/cirrest-audio-hal-real" ] && \
    set_perm "$MODPATH/system/vendor/bin/hw/cirrest-audio-hal-real" 0 2000 0755
[ -f "$MODPATH/system/vendor/bin/hw/cirrest-effects-factory" ] && \
    set_perm "$MODPATH/system/vendor/bin/hw/cirrest-effects-factory" 0 2000 0755
[ -f "$MODPATH/system/vendor/bin/hw/cirrest-dlopen-probe" ] && \
    set_perm "$MODPATH/system/vendor/bin/hw/cirrest-dlopen-probe" 0 2000 0755
ui_print "- "
ui_print "- "
ui_print "- ⚠该模块为免费模块，自己逆向半年kernel适配手搓的成果之一⚠"
ui_print "- ⚠禁止任何形式商业化、收费、二改⚠"
ui_print "- ⚠该模块所有文件均已打上数字水印，均可追溯⚠"