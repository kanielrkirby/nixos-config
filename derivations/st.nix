{ pkgs, suckless }:

pkgs.stdenv.mkDerivation {
  pname = "st";
  version = "git";

  src = suckless;

  postUnpack = ''
    sourceRoot="$sourceRoot/st"
  '';

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
