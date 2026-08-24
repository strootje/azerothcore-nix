{ fetchFromGitHub, lib }:

fetchFromGitHub {
  owner = "lichborne-ac";
  repo = "mod-levelsync";

  rev = "27b50eb";
  hash = lib.fakeHash;
}
