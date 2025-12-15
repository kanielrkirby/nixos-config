{ pkgs, dotfiles, ... }:

pkgs.stdenv.mkDerivation {
  pname = "dwlb";
  version = "custom";

  src = "${dotfiles}/patches/dwlb/dwlb";

  nativeBuildInputs = with pkgs; [ pkg-config wayland-scanner ];

  buildInputs = with pkgs; [ wayland wayland-protocols pixman fcft ];

  makeFlags = [ "PREFIX=$(out)" ];

  preBuild = ''
    make clean
  '';
}
