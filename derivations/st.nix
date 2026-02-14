{ pkgs, dotfiles, st-src, ... }:

pkgs.stdenv.mkDerivation {
  pname = "st";
  version = "git";

  src = st-src;

  patches = [
    "${dotfiles}/patches/st/01-config.patch"
  ];

  strictDeps = true;

  nativeBuildInputs = with pkgs; [
    pkg-config
    ncurses
    fontconfig
    freetype
  ];

  buildInputs = with pkgs; [
    xorg.libX11
    xorg.libXft
  ];

  makeFlags = [
    "PKG_CONFIG=${pkgs.stdenv.cc.targetPrefix}pkg-config"
  ];

  preBuild = ''
    make clean
  '';

  preInstall = ''
    export TERMINFO=$out/share/terminfo
    mkdir -p $TERMINFO
  '';

  installFlags = [
    "PREFIX=$(out)"
  ];
}
