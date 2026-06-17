{ pkgs, ... }:

let
  version = "0.4.1";
  src = pkgs.fetchFromGitHub {
    owner = "coleam00";
    repo = "Archon";
    rev = "v${version}";
    hash = "sha256-pSuCiTB9APMczkFfx+iypcQj83RgYRpSLhib3V2b4k4=";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "archon";
  inherit version src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/archon" "$out/bin"
    cp -R . "$out/share/archon"

    cat > "$out/bin/archon" <<EOF
#!/bin/sh
exec ${pkgs.bun}/bin/bun "$out/share/archon/packages/cli/src/cli.ts" "\$@"
EOF
    chmod 0755 "$out/bin/archon"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Archon CLI for deterministic AI coding workflows";
    homepage = "https://github.com/coleam00/Archon";
    license = licenses.mit;
    mainProgram = "archon";
    platforms = platforms.linux;
  };
}
