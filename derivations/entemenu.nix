{ pkgs, ... }:

pkgs.writeShellScriptBin "entemenu" /* bash */ ''
  gpg -qd "''${ENTE_AUTH_FILE:-$HOME/Documents/ente_auth/ente_auth.txt.gpg}" \
  | dmenu -l 20 -i -p "OTP:" \
  | sed 's/.*secret=\([^&]*\).*/\1/' \
  | tr -d ' +\-' \
  | "${pkgs.python312Packages.oathtool}/bin/oathtool" -b --totp \
  | xclip -sel clip
''
