{ pkgs, dotfiles }:

pkgs.stdenv.mkDerivation {
  pname = "dwmblocks";
  version = "custom";

  src = "${dotfiles}/patches/dwmblocks/dwmblocks";

  patches = [
    "${dotfiles}/patches/dwmblocks/01-config.patch"
  ];

  buildInputs = with pkgs; [ xorg.libX11 ];

  makeFlags = [ "PREFIX=$(out)" ];

  preBuild = ''
    make clean
    rm -f blocks.h
  '';
}
