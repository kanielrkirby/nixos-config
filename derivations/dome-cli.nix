{ pkgs, src, ... }:

let
  version = src.shortRev or src.rev or "unstable";
in
pkgs.buildGoModule {
  pname = "dome-cli";
  inherit version src;

  vendorHash = "sha256-O+CyQwmqi9OQdNjGGsCgcC+XCfk4MhJUC6NXk//xIhA=";

  doCheck = true;

  meta = with pkgs.lib; {
    description = "CLI tool for managing Dome helpdesk ticket workflows";
    homepage = "https://github.com/domesoftware/dome-cli";
    license = licenses.mit;
    mainProgram = "dome";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
