{ lib
, gems
, stdenv
, jekyllBuildFlags ? []
, ...
}:
with lib;
stdenv.mkDerivation {
  name = "szakallas.eu";
  version = "unstable";
  src = ./src;
  buildInputs = [ gems ];
  buildPhase = ''
    ${gems}/bin/bundle exec jekyll ${concatStringsSep " " ([ "build" ] ++ jekyllBuildFlags)}
  '';
  installPhase = ''
    cp -r _site $out
  '';
}
