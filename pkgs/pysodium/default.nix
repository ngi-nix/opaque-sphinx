{ pkgs }:
with pkgs;
let py3Pkgs = pkgs.python3.pkgs;
in py3Pkgs.buildPythonPackage rec {
  pname = "pysodium";
  version = "0.7.5";

  src = py3Pkgs.fetchPypi {
    inherit pname version;
    sha256 = "0vlcvx3rrhp72fbb6kl1rj51cwpjknj2d1xasmmsfif95iwi026p";
  };

  propagatedBuildInputs = [ libsodium ];

  # Make pysodium find libsodium. We use the same approach here as
  # python-modules/libnacl.
  postPatch = let soext = stdenv.hostPlatform.extensions.sharedLibrary;
  in ''
    substituteInPlace ./pysodium/__init__.py \
      --replace "ctypes.util.find_library('sodium') or ctypes.util.find_library('libsodium')" "'${libsodium}/lib/libsodium${soext}'"
  '';
}
