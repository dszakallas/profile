{ self, pkgs, lib, config, inputs, ... }:
with lib;
let
  ruby = pkgs.ruby;
  gems = pkgs.bundlerEnv {
    inherit ruby;
    name = "szakallas.eu-env";
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
  jekyllCmd = "${gems.wrappedRuby}/bin/bundle exec jekyll";
in {
  languages.javascript = {
    enable = true;
    npm = {
      enable = true;
      install.enable = true;
    };
    directory = "./hack";
   };

  env = {
    JEKYLL_CACHE_DIR = "${self}/.jekyll-cache";
    JEKYLL_METADATA = "${self}/.jekyll-metadata";
  };

  packages = [ gems gems.wrappedRuby ] ++ (with pkgs; [ git bundix ]);

  scripts = {
    upload.exec = "cd hack && npm run upload --silent -- $@";
  };

  outputs = {
    prod = pkgs.callPackage ./site.nix {
      inherit gems;
    };
    staging = pkgs.callPackage ./site.nix {
      inherit gems;
      jekyllBuildFlags = [ "--future" ];
    };
  };

  processes = {
    serve = {
      exec = concatStringsSep " " [
        "${jekyllCmd}"
        "serve"
        "--port" "4000"
        "--disable-disk-cache"
        "--future"
        "--incremental"
        "-l"
        "--livereload-port" "35729"
        "--source" "./src"
      ];
    };
  };
}
