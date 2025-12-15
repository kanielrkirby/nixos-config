{ pkgs, dotfiles, ... }:

pkgs.dwl.overrideAttrs (oldAttrs: {
  src = "${dotfiles}/patches/dwl/dwl";

  patches = [
    "${dotfiles}/patches/dwl/01-ipc.patch"
    "${dotfiles}/patches/dwl/02-config.patch"
  ];

  # Your fork needs wlroots 0.19, upstream nixpkgs dwl pins 0.18
  buildInputs = map (p: if p.pname or "" == "wlroots" then pkgs.wlroots_0_19 else p) (oldAttrs.buildInputs or []);

  preBuild = ''
    make clean
  '' + (oldAttrs.preBuild or "");
})
