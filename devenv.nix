{
  self,
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib;
let
  gems = pkgs.bundlerEnv {
    inherit (pkgs) ruby;
    name = "profile-env";
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
  jekyllCmd = "${gems.wrappedRuby}/bin/bundle exec jekyll";
in
{
  languages.javascript = {
    enable = true;
    npm = {
      enable = true;
      install.enable = true;
    };
    directory = "./hack";
  };

  packages = [
    gems
    gems.wrappedRuby
  ]
  ++ (with pkgs; [ bundix ]);

  scripts = {
    upload.exec = "cd hack && npm run upload --silent -- $@";
  };

  outputs = {
    production = pkgs.callPackage ./site.nix {
      jekyllEnv = "production";
      inherit gems;
    };
    staging = pkgs.callPackage ./site.nix {
      inherit gems;
      jekyllBuildFlags = [ "--future" ];
    };
  };

  git-hooks.hooks = {
    markdownlint = {
      excludes =
        let
          older_posts_im_not_going_to_fix = (
            builtins.map (yyyy: "src/_posts/${builtins.toString yyyy}-.*\\.md") (
              builtins.genList (x: x + 2014) 10
            )
          );
        in
        older_posts_im_not_going_to_fix ++ [ "src/about.md" ];
    };
    nixfmt-rfc-style = {
      excludes = [ "gemset.nix" ];
    };
    bundix = {
      enable = true;
      entry = "bundix";
      files = "Gemfile(\\.lock)?$";
    };
  };

  processes = {
    serve = {
      exec = concatStringsSep " " [
        "${jekyllCmd}"
        "serve"
        "--port"
        "4000"
        "--disable-disk-cache"
        "--future"
        "--incremental"
        "-l"
        "--livereload-port"
        "35729"
        "--source"
        "./src"
      ];
    };
  };
}
