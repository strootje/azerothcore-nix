{ fetchFromGitHub, lib }:

fetchFromGitHub {
  owner = "wishmaster117";
  repo = "mod-multibot-bridge";

  rev = "d42b23d";
  hash = lib.fakeHash;
}
