{ pkgs, dotfiles }:

pkgs.dwm.overrideAttrs (oldAttrs: {
  src = "${dotfiles}/patches/dwm/dwm";

  patches = [
    "${dotfiles}/patches/dwm/01-config.patch"
  ];

  preBuild = ''
    make clean
    makeFlagsArray+=(
      "PREFIX=$out"
      "CC=$CC"
    )
  '';
})
