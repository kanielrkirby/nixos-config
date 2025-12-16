{ pkgs, suckless }:

pkgs.stdenv.mkDerivation {
  pname = "dwmblocks";
  version = "custom";

  src = suckless;

  postUnpack = ''
    sourceRoot="$sourceRoot/dwmblocks"
  '';

  buildInputs = with pkgs; [ xorg.libX11 ];

  makeFlags = [ "PREFIX=$(out)" ];

  preBuild = ''
    make clean
    rm -f blocks.h
  '';
}
