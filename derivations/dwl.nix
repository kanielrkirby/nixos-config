{ pkgs, suckless }:

pkgs.dwl.overrideAttrs (oldAttrs: {
  src = suckless;

  postUnpack = ''
    sourceRoot="$sourceRoot/dwl"
  '';

  # Your fork needs wlroots 0.19, upstream nixpkgs dwl pins 0.18
  buildInputs = map (p: if p.pname or "" == "wlroots" then pkgs.wlroots_0_19 else p) (oldAttrs.buildInputs or []);

  preBuild = ''
    make clean
  '' + (oldAttrs.preBuild or "");
})
