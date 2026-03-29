{
  self,
  config,
  inputs,
  pkgs,
  ...
}@args:
let
  lib = args.lib // (import ./devenv/lib { inherit (inputs) nixpkgs; });
  pkgs = args.pkgs;
in
with lib;
with pkgs;
let
  ruby = pkgs.ruby;
  gems = pkgs.bundlerEnv {
    inherit ruby;
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
  };
  languages.ruby = {
    enable = true;
    package = ruby;
  };

  profiles.agents.module =
    { ... }:
    let
      mcpServers = {
        playwright = {
          type = "stdio";
          command = "${playwright-mcp}/bin/playwright-mcp";
        };
      };
    in
    {
      imports = [ ./devenv/modules/agents.nix ];
      config = {
        packages = with pkgs; [ playwright-mcp ];
        agents.gemini = {
          enable = true;
          settings = {
            enable = true;
            inherit mcpServers;
          };
        };
        agents.augment = {
          enable = true;
          settings = {
            enable = true;
            inherit mcpServers;
          };
        };
        agents.vscode = {
          enable = true;
          settings = {
            enable = true;
            inherit mcpServers;
          };
        };
      };
    };

  packages = with pkgs; [
    bundix
  ];

  scripts = {
    upload.exec = "npm run upload --silent -- $@";
    "copy-vendor-assets".exec = "npm run copy-vendor-assets --silent -- $@";
    "build".exec = "${jekyllCmd} build --source src --destination _site";
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
      excludes = [
        "gemset.nix"
        "devenv/pkgs/npm/_.*\\.nix"
      ];
    };
    bundix = {
      enable = true;
      entry = "bundix";
      files = "Gemfile(\\.lock)?$";
    };
    vendor-assets = {
      enable = true;
      name = "vendor-assets";
      entry = "${pkgs.nodejs}/bin/node hack/copy-vendor-assets.js src/assets/vendor";
      files = "(package\\.json|package-lock\\.json)$";
      pass_filenames = false;
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
