{ pkgs, suckless }:

pkgs.stdenv.mkDerivation {
  pname = "dwlblocks";
  version = "custom";

  src = suckless;

  postUnpack = ''
    sourceRoot="$sourceRoot/dwlblocks"
  '';

  buildInputs = with pkgs; [ wayland wayland-protocols ];

  makeFlags = [ "PREFIX=$(out)" ];

  preBuild = ''
    make clean
    rm -f blocks.h
  '';
}
