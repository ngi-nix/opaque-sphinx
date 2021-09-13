{ pkgs, version, src, buildPythonPackage }:
with pkgs;
buildPythonPackage rec {
  pname = "pysodium";
  inherit version src;

  propagatedBuildInputs = [ libsodium ];

  # Make pysodium find libsodium. We use the same approach here as
  # python-modules/libnacl.
  postPatch = let soext = stdenv.hostPlatform.extensions.sharedLibrary;
  in ''
    substituteInPlace ./pysodium/__init__.py \
      --replace "ctypes.util.find_library('sodium') or ctypes.util.find_library('libsodium')" "'${libsodium}/lib/libsodium${soext}'"
  '';
}
