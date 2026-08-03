{
  lib,
  gems,
  stdenv,
  texliveFull ? null,
  python3,
  jekyllBuildFlags ? [ ],
  jekyllEnv ? "development",
  withoutCvPdf ? false,
  ...
}:
with lib;
let
  pythonEnv = python3.withPackages (ps: [
    ps.pyyaml
    ps.jinja2
  ]);
  generateCvFlags = if withoutCvPdf then "" else " --with-latex";
in
stdenv.mkDerivation {
  name = "profile";
  version = "unstable";
  src = ./.;
  buildInputs = [
    gems
    pythonEnv
  ]
  ++ (optional (!withoutCvPdf) texliveFull);
  buildPhase = ''
    export HOME=$TMPDIR
    export JEKYLL_ENV=${jekyllEnv}

    # Generate CV HTML (and PDF if withoutCvPdf is false)
    python3 hack/generate-cv.py${generateCvFlags}

    # Build Jekyll site
    ${gems}/bin/bundle exec jekyll ${
      concatStringsSep " " (
        [
          "build"
          "--source"
          "src"
        ]
        ++ jekyllBuildFlags
      )
    }
  '';
  installPhase = ''
    cp -r _site $out
  '';
}
