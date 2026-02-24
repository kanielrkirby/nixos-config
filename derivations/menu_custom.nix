{ pkgs, ... }:

pkgs.writeShellScriptBin "menu_custom" /* bash */ ''
  if [ -n "$WAYLAND_DISPLAY" ]; then
    MENU_CMD="bemenu"
  elif [ -n "$DISPLAY" ]; then
    MENU_CMD="dmenu"
  else
    echo "No display server detected" >&2
    exit 1
  fi

  MENU_OPTS="''${MENU_CUSTOM_OPTS:--l 10}"

  runinterm() {
    setsid st -e sh -c "$1; read -sn 1" >/dev/null 2>&1 &
  }

  runprefix="exec"
  extracommands=",\n&\n'\n"
  if [ "$1" = "runinterm" ]; then
    runprefix="runinterm"
  else
    extracommands=">\n$extracommands"
  fi

  run_cmd() {
    case "$1" in
      ">") "$0" runinterm ;;
      ",") "$runprefix" rbwm ;;
      "&") "$runprefix" wifimenu ;;
      "'") "$runprefix" dmente ;;
      *) "$runprefix" "$1" ;;
    esac
  }

  echo "$PATH" | tr ":" "\n" | \
  while read -r dir; do
    [ -d "$dir" ] && find "$dir" -maxdepth 1 \( -type f -o -type l \) -executable -printf "%f\n" 2>/dev/null
  done | sort -u | cat <(printf "$extracommands") - | $MENU_CMD $MENU_OPTS | while read cmd; do
    [ -n "$cmd" ] && run_cmd "$cmd"
  done
''
