{
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

clangStdenv.mkDerivation rec {
  pname = "acore";
  version = "master";

  src = fetchFromGitHub {
    owner = "azerothcore";
    repo = "azerothcore";

    rev = version;
    hash = "sha256-AZV+5YZqdArcsM6kpHiBMQJwUVMzMOrajcbO6aKie+A=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    git
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
}
