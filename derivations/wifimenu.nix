{ pkgs, ... }:

pkgs.writeShellScriptBin "wifimenu" /* bash */ ''
  bssid="$(nmcli -f "BSSID,SSID,SIGNAL,RATE,BARS,SECURITY" dev wifi list | sed -n '1!p' | dmenu -p "Select WiFi: " -l 20 | cut -d' ' -f1)"
  pass="$(echo "" | dmenu -p "Enter password: ")"
  nmcli device wifi connect "$bssid" password "$pass"
''
