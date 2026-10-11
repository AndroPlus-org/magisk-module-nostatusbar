REPLACE="
"

HEIGHTS="0 1 2 3"
DEFAULT_HEIGHT=0

# Wait for a volume key press. Prints "up" or "down", fails on timeout.
get_key() {
  local ev
  while true; do
    ev=$(timeout 10 getevent -lqc 1 2>/dev/null) || return 1
    case "$ev" in
      *KEY_VOLUMEUP*DOWN*) echo up; return 0 ;;
      *KEY_VOLUMEDOWN*DOWN*) echo down; return 0 ;;
    esac
  done
}

HEIGHT=$DEFAULT_HEIGHT
if $BOOTMODE && command -v getevent >/dev/null 2>&1; then
  ui_print "- Select status bar height"
  ui_print "  Vol+ : next   Vol- : select"
  ui_print "  (no input for 10 seconds = ${DEFAULT_HEIGHT}px)"
  idx=1
  while true; do
    HEIGHT=$(echo $HEIGHTS | cut -d' ' -f$idx)
    ui_print "  > ${HEIGHT}px"
    key=$(get_key) || { HEIGHT=$DEFAULT_HEIGHT; break; }
    [ "$key" = "down" ] && break
    idx=$((idx + 1))
    [ -z "$(echo $HEIGHTS | cut -d' ' -f$idx -s)" ] && idx=1
  done
fi
[ -d "$MODPATH/overlays/${HEIGHT}px" ] || HEIGHT=$DEFAULT_HEIGHT
ui_print "- Status bar height: ${HEIGHT}px"

mkdir -p "$MODPATH/system/product/overlay"
cp -f "$MODPATH/overlays/${HEIGHT}px/"*.apk "$MODPATH/system/product/overlay/"
rm -rf "$MODPATH/overlays" "$MODPATH/src" "$MODPATH/build.sh"
