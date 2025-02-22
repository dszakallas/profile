{
  lib,
  gems,
  stdenv,
  jekyllBuildFlags ? [ ],
  jekyllEnv ? "development",
  ...
}:
with lib;
stdenv.mkDerivation {
  name = "profile";
  version = "unstable";
  src = ./src;
  buildInputs = [ gems ];
  buildPhase = ''
    export JEKYLL_ENV=${jekyllEnv}
    ${gems}/bin/bundle exec jekyll ${concatStringsSep " " ([ "build" ] ++ jekyllBuildFlags)}
  '';
  installPhase = ''
    cp -r _site $out
  '';
}
