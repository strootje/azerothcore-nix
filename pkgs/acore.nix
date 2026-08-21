{
  lib,

  clangStdenv,
  fetchFromGitHub,

  cmake,
  ninja,
  git,

  boost,
  openssl,
  mysql84,

  zlib,
  bzip2,
  xz,

  readline,
  ncurses,
}:

{
  modules ? { },
}:

let
  isPlayerBotEnabled = builtins.hasAttr "mod-playerbots" modules;
  srcOwner = if isPlayerBotEnabled then "mod-playerbots" else "azerothcore";
  srcVersion = if isPlayerBotEnabled then "efe123f" else "69f387e";
  srcHash =
    if isPlayerBotEnabled then
      "sha256-CB6VYl2pFE8FpowsvEeaDMUtJJSHzb4tE/v6c/GKFfA="
    else
      "sha256-AZV+5YZqdArcsM6kpHiBMQJwUVMzMOrajcbO6aKie+A=";
in

clangStdenv.mkDerivation rec {
  pname = "acore";
  version = srcVersion;

  src = fetchFromGitHub {
    owner = srcOwner;
    repo = "azerothcore-wotlk";

    rev = version;
    hash = srcHash;
  };

  postPatch = lib.concatLines (
    lib.mapAttrsToList (name: src: ''
      rm -rf modules/${name}
      cp -r ${src} modules/${name}
    '') modules
  );

  nativeBuildInputs = [
    cmake
    ninja
    git
  ];

  cmakeFlags = [
    "-DAPPS_BUILD=all"
    "-DTOOLS_BUILD=db-only"
    "-DSCRIPTS=static"
    "-DMODULES=static"
    "-DWITH_WARNINGS=ON"
  ];

  buildInputs = [
    boost
    openssl
    mysql84

    zlib
    bzip2
    xz

    readline
    ncurses
  ];

  postInstall = ''
    mkdir -p $out/sql-files
    srcRoot="$(readlink -f "$PWD/..")"
    ( cd "$srcRoot" && find data -name '*.sql' -print -exec cp --parents --no-preserve=mode -t $out/sql-files {} + )
    ( cd "$srcRoot" && find modules -name '*.sql' -print -exec cp --parents --no-preserve=mode -t $out/sql-files {} + ) 
  '';
}
