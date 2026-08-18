{ fetchzip }:

fetchzip {
  pname = "ac-client-data";
  version = "v20.0";

  url = "https://github.com/wowgaming/client-data/releases/download/v20.0/data.zip";
  hash = "sha256-xZJvdDNyV0gv7mbFhutLSbETqEWPUlcBgPnB44eCbuA=";
  stripRoot = false;
}
