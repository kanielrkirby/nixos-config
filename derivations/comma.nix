{ pkgs, ... }:

pkgs.writeShellScriptBin "," /* bash */ ''
  count=$((1 + $(echo "$1" | tr -cd ',' | wc -c)))
  if [ "$count" = 1 ]; then
    if [ "$2" = "--" ]; then
      # , tealdeer -- tldr --help
      nix shell "nixpkgs#$1" --command "''${@:3}"
    else
      # , tealdeer --help
      nix run "nixpkgs#$1" -- "''${@:2}"
    fi
  else
    nix shell nixpkgs#''${1//,/ nixpkgs#} --command "''${@:2}"
  fi
''
