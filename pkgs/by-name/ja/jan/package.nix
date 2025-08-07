{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
  yarn-berry_4,
  nodejs,
  rustPlatform,
  openssl,
  pkg-config,
}:

let
  yarn-berry = yarn-berry_4;
  pname = "Jan";
  version = "0.6.6";
  src = fetchFromGitHub {
    owner = "menloresearch";
    repo = "jan";
    tag = "v${version}";
    hash = "sha256-I/8CZAWALyMN7GgVc6i2zaFbhIwXAQLxHSYhu07KutY=";
  };
  frontend-build = stdenvNoCC.mkDerivation (finalAttrs: {
    inherit version src;
    pname = "jan-app";

    missingHashes = ./missing-hashes.json;
    offlineCache = yarn-berry.fetchYarnBerryDeps {
      inherit (finalAttrs) src missingHashes;
      hash = "sha256-SazjmGTae1wvbZKZx/NvbRnWW5IeofmH1hg/DXBO/H8=";
    };
    nativeBuildInputs = [
      yarn-berry
      yarn-berry.yarnBerryConfigHook
      nodejs
    ];
    yarnBuildScript = "build:web";
    installPhase = ''
      cp -r out $out
    '';
  });
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  sourceRoot = "${src.name}/src-tauri";
  cargoLock =
    let
      fixupLockFile = path: builtins.readFile path;
    in
    {
      lockFileContents = fixupLockFile ./Cargo.lock;
      outputHashes = {
        "fix-path-env-0.0.0" = "sha256-SHJc86sbK2fA48vkVjUpvC5FQoBOno3ylUV5J1b4dAk=";
      };
    };

  patches = [
    ./01-replace-git-deps.patch
  ];

  postPatch = ''
    # Insert Cargo.lock
    ln -s ${./Cargo.lock} Cargo.lock

    # Replace frontend artifact dir
    mkdir -p frontend-build
    cp -R ${frontend-build}/dist frontend-build

    substituteInPlace tauri.conf.json --replace '"frontendDist": "../web-app/dist",' '"distDir": "frontend-build/dist",'
  '';

  nativeBuildInputs = [
    pkg-config
  ];
  buildInputs = [
    openssl
  ];

  meta = {
    changelog = "https://github.com/janhq/jan/releases/tag/v${version}";
    description = "Jan is an open source alternative to ChatGPT that runs 100% offline on your computer";
    homepage = "https://github.com/janhq/jan";
    license = lib.licenses.agpl3Plus;
    mainProgram = "jan";
    maintainers = with lib.maintainers; [ turtton ];
  };
}
