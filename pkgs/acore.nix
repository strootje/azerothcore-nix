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

clangStdenv.mkDerivation rec {
  pname = "acore";
  version = "master";

  src = fetchFromGitHub {
    owner = "azerothcore";
    repo = "azerothcore";

    rev = version;
    hash = "sha256-AZV+5YZqdArcsM6kpHiBMQJwUVMzMOrajcbO6aKie+A=";
  };

  postPatch = lib.concatLines (
    lib.mapAttrsToList (name: src: "ln -s ${src} modules/${name}") modules
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
    # "-DBoost_USE_STATIC_LIBS=ON"
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
    mkdir -p $out/src
    cp -r "${src}/data" $out/src
    cp -r "${src}/modules" $out/src
  '';
}
