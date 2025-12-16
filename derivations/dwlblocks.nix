{ pkgs, dotfiles }:

pkgs.stdenv.mkDerivation {
  pname = "dwlblocks";
  version = "custom";

  src = "${dotfiles}/patches/dwlblocks/dwlblocks";

  buildInputs = with pkgs; [ wayland wayland-protocols ];

  makeFlags = [ "PREFIX=$(out)" ];

  preBuild = ''
    make clean
    rm -f blocks.h
  '';
}
