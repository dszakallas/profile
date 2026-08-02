{
  self,
  config,
  inputs,
  lib,
  pkgs,
  bikeshed,
  ...
}@args:
let
  lib' = bikeshed.lib;
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
  imports = [
    bikeshed.devenvModules.recommended
  ];

  profiles = lib'.importRec1 ./devenv args;

  env = {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    PLAYWRIGHT_USER_DATA_DIR = "${config.devenv.root}/.playwright/user-data";
    PLAYWRIGHT_OUTPUT_DIR = "${config.devenv.root}/.playwright/output";
  };

  enterShell = ''
    export NODE_PATH="${config.devenv.root}/node_modules:$NODE_PATH"
    CHROMIUM_BIN="$(find -L "${pkgs.playwright-driver.browsers}" -name chrome-headless-shell -type f -print -quit)"
    export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH="$CHROMIUM_BIN"
    export PLAYWRIGHT_LAUNCH_OPTIONS_EXECUTABLE_PATH="$CHROMIUM_BIN"
  '';

  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_24;
    npm = {
      enable = true;
      install.enable = true;
    };
  };

  languages.ruby = {
    enable = true;
    package = ruby;
  };

  packages = with pkgs; [
    bundix
    nodejs_24
    playwright-driver
    fswatch
    (python3.withPackages (ps: [
      ps.pyyaml
      ps.jinja2
    ]))
  ];

  scripts = {
    upload.exec = "npm run upload --silent -- $@";
    "copy-vendor-assets".exec = "npm run copy-vendor-assets --silent -- $@";
    "generate-cv".exec = ''python3 hack/generate-cv.py "$@"'';
    "build-cv".exec = ''python3 hack/generate-cv.py --with-latex "$@"'';
    "build".exec = ''
      generate-cv
      ${jekyllCmd} build --source src --destination _site
    '';
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
    nixfmt = {
      excludes = [
        "gemset\\.nix"
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
    watch-cv = {
      exec = ''
        echo "Watching src/cv/cv.yaml and src/cv/templates/ for changes..."
        fswatch -o src/cv/cv.yaml src/cv/templates/ | while read _; do
          echo "CV sources changed, regenerating..."
          generate-cv
        done
      '';
    };
    serve = {
      ports.http.allocate = 4000;
      ports.livereload.allocate = 35729;
      exec = lib.concatStringsSep " " [
        "${jekyllCmd}"
        "serve"
        "--port"
        "${toString config.processes.serve.ports.http.value}"
        "--disable-disk-cache"
        "--future"
        "--incremental"
        "-l"
        "--livereload-port"
        "${toString config.processes.serve.ports.livereload.value}"
        "--source"
        "./src"
      ];
    };
  };
}
