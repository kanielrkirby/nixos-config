{ pkgs }:

pkgs.writeShellScriptBin "battery-notify" ''
  STATE_FILE="/tmp/battery-notify-state"
  LAST_STATUS_FILE="/tmp/battery-notify-last-status"
  NOTIFICATION_ID_FILE="/tmp/battery-notify-id"
  
  echo "none" > "$STATE_FILE"
  echo "Unknown" > "$LAST_STATUS_FILE"
  echo "0" > "$NOTIFICATION_ID_FILE"
  
  BAT_PATH="/sys/class/power_supply/BAT0"
  DBUS_ENV="DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
  
  notify() {
    local pct=$1
    local id=$(cat "$NOTIFICATION_ID_FILE")
    local flag=""
    [ "$id" != "0" ] && flag="-r $id"
    
    id=$(eval "$DBUS_ENV ${pkgs.libnotify}/bin/notify-send -u critical -p $flag 'Battery Low' 'Battery at ''${pct}%!'")
    echo "$id" > "$NOTIFICATION_ID_FILE"
  }
  
  clear_notification() {
    local id=$(cat "$NOTIFICATION_ID_FILE")
    [ "$id" != "0" ] && eval "$DBUS_ENV ${pkgs.libnotify}/bin/notify-send -t 1 -r $id ' ' ' '" 2>/dev/null
    echo "0" > "$NOTIFICATION_ID_FILE"
  }
  
  get_threshold() {
    local pct=$1
    [ "$pct" -le 3 ] && echo "3" && return
    [ "$pct" -le 5 ] && echo "5" && return
    [ "$pct" -le 10 ] && echo "10" && return
    [ "$pct" -le 20 ] && echo "20" && return
    echo "none"
  }
  
  check_and_notify() {
    local pct=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo "100")
    local status=$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unknown")
    local last_notified=$(cat "$STATE_FILE")
    local last_status=$(cat "$LAST_STATUS_FILE")
    
    # Unplug event at ≤20%
    [ "$last_status" != "Discharging" ] && [ "$status" = "Discharging" ] && [ "$pct" -le 20 ] && {
      notify "$pct"
      echo "$(get_threshold "$pct")" > "$STATE_FILE"
    }
    
    # Check thresholds when discharging
    if [ "$status" = "Discharging" ]; then
      local threshold=$(get_threshold "$pct")
      [ "$threshold" != "none" ] && [ "$threshold" != "$last_notified" ] && {
        notify "$pct"
        echo "$threshold" > "$STATE_FILE"
      }
    else
      # Charging - clear notification and reset state
      clear_notification
      [ "$pct" -gt 20 ] && echo "none" > "$STATE_FILE"
    fi
    
    echo "$status" > "$LAST_STATUS_FILE"
  }
  
  check_and_notify
  
  # Poll every 10 seconds
  ( while true; do sleep 10; check_and_notify; done ) &
  
  # Watch plug/unplug events
  ${pkgs.systemd}/bin/udevadm monitor --kernel --subsystem-match=power_supply 2>/dev/null | \
  while read -r line; do
    [[ "$line" == *"power_supply"* ]] && { sleep 0.1; check_and_notify; }
  done
''
