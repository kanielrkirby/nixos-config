{ pkgs, ... }:

let
  version = "1.6.12";
  src = pkgs.fetchFromGitHub {
    owner = "ianjwhite99";
    repo = "opencode-with-claude";
    rev = "v${version}";
    hash = "sha256-nZLHNdF0RW5g3Apw56DDgVNSIRB0S4Gy4bNBhp2WvmU=";
  };
in
pkgs.buildNpmPackage {
  pname = "opencode-with-claude";
  inherit version src;

  npmDepsHash = "sha256-QITFqyxPo2zkE5xfQdd3QNSgMWC1pFOSRbHgRIGCvac=";
  npmBuildScript = "build";

  postPatch = ''
    cp ${./opencode_with_claude-package-lock.json} package-lock.json
  '';

  meta = with pkgs.lib; {
    description = "OpenCode plugin to use Claude Max via Meridian";
    homepage = "https://github.com/ianjwhite99/opencode-with-claude";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
