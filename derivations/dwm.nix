{ pkgs, suckless }:

pkgs.dwm.overrideAttrs (oldAttrs: {
  src = suckless;

  postUnpack = ''
    sourceRoot="$sourceRoot/dwm"
  '';

  preBuild = ''
    make clean
    makeFlagsArray+=(
      "PREFIX=$out"
      "CC=$CC"
    )
  '';
})
