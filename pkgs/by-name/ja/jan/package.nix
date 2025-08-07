{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
  yarn-berry_4,
  nodejs,
  rustPlatform,
  openssl,
  glib,
  librsvg,
  webkitgtk_4_1,
  uv,
  pkg-config,
  nix-update-script,
}:

let
  yarn-berry = yarn-berry_4;
  pname = "Jan";
  version = "0.6.8";
  src = fetchFromGitHub {
    owner = "menloresearch";
    repo = "jan";
    tag = "v${version}";
    hash = "sha256-FqL01YXsFtMaHijMRNZE9cA4WSgSs0b2HlUknyVMpvA=";
  };
  frontend-build = stdenvNoCC.mkDerivation (finalAttrs: {
    inherit version src;
    pname = "jan-app";

    postPatch = ''
      # Replace yarn.lock
      rm yarn.lock
      ln -s ${./yarn.lock} yarn.lock
    '';

    missingHashes = ./missing-hashes.json;
    offlineCache = yarn-berry.fetchYarnBerryDeps {
      inherit (finalAttrs) src postPatch missingHashes;
      hash = "sha256-V753XDGBrrUPMSlJKHlie/XNFob/FSxmxEOTkFCr7kE=";
    };

    patches = [
      ./02-disable-yarn-network.patch
    ];

    nativeBuildInputs = [
      yarn-berry
      yarn-berry.yarnBerryConfigHook
      nodejs
    ];
    buildPhase = ''
      yarn run build:core
      yarn workspace @janhq/web-app vite build
    '';
    installPhase = ''
      mkdir -p $out/dist
      cp -r web-app/dist $out/dist
      cp core/package.tgz $out
    '';
  });
  extension-build = stdenvNoCC.mkDerivation (finalAttrs: {
    inherit version;
    src = "${src}/extensions";
    pname = "jan-extensions";

    postPatch = ''
      # Replace yarn.lock
      rm yarn.lock
      cp ${./extensions-yarn.lock} yarn.lock

      # Install core
      ln -s ${frontend-build}/package.tgz package.tgz
      substituteInPlace yarn.lock \
                        assistant-extension/package.json \
                        conversational-extension/package.json \
                        download-extension/package.json \
                        llamacpp-extension/package.json \
                        --replace-fail '../../core/package.tgz' '../package.tgz'
    '';

    missingHashes = ./extensions-missing-hashes.json;
    offlineCache = yarn-berry.fetchYarnBerryDeps {
      inherit (finalAttrs) src postPatch missingHashes;
      hash = "sha256-G9bryA9PepY2D/B5y9njM9BVFg73ie1YLupX7Bi4Gjo=";
    };

    patches = [
      ./02-disable-yarn-network.patch
    ];

    nativeBuildInputs = [
      yarn-berry
      yarn-berry.yarnBerryConfigHook
      nodejs
    ];
    buildPhase = ''
      yarn run build:publish
    '';
    installPhase = ''
      cp -r pre-install $out/pre-install
    '';
  });
in
rustPlatform.buildRustPackage (finalAttrs: {
  inherit pname version src;

  sourceRoot = "${src.name}/src-tauri";
    #cargoHash = "sha256-/sbLT39h7S+UELFlRuGNDp6ZXyIXA//4uR1tyfvw6kI=";
  cargoDepsName = finalAttrs.pname;
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
    # Replace Cargo.lock
    rm Cargo.lock
    ln -s ${./Cargo.lock} Cargo.lock

    # Replace frontend artifact dir
    mkdir -p frontend-build
    cp -R ${frontend-build}/dist frontend-build
    substituteInPlace tauri.conf.json --replace '"frontendDist": "../web-app/dist",' '"frontendDist": "frontend-build/dist",'

    # Replace pre-install packages
    mkdir -p resources/pre-install
    cp -R ${extension-build}/pre-install/* resources/pre-install/

    # Insert uv package
    mkdir -p resources/bin
    ln -s ${uv} resources/bin/uv-x86_64-unknown-linux-gnu
  '';

  nativeBuildInputs = [
    pkg-config
  ];
  buildInputs = [
    openssl
    glib
    librsvg
    webkitgtk_4_1
  ];

  passthru = {
      inherit (finalAttrs) offlineCache;
      updateScript = nix-update-script {};
    };

  meta = {
    changelog = "https://github.com/janhq/jan/releases/tag/v${version}";
    description = "Jan is an open source alternative to ChatGPT that runs 100% offline on your computer";
    homepage = "https://github.com/janhq/jan";
    license = lib.licenses.agpl3Plus;
    mainProgram = "jan";
    maintainers = with lib.maintainers; [ turtton ];
  };
})
