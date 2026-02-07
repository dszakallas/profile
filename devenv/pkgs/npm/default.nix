{ nodejs_24, callPackage }:
callPackage ./_default.nix {
  nodejs = nodejs_24;
}
