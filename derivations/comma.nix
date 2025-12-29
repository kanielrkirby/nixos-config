{ pkgs, ... }:

pkgs.writeShellScriptBin "," /* bash */ ''
  nix shell nixpkgs#''${1//,/ nixpkgs#} --command "''${@:2}"
''
