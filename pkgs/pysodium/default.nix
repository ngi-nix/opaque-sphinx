{ version, sha256, stdenv, lib, buildPythonPackage, fetchPypi, libsodium }:
buildPythonPackage rec {
  pname = "pysodium";
  inherit version;

  src = fetchPypi { inherit pname version sha256; };

  propagatedBuildInputs = [ libsodium ];

  # Make pysodium find libsodium. We use the same approach here as
  # python-modules/libnacl.
  postPatch = let soext = stdenv.hostPlatform.extensions.sharedLibrary;
  in ''
    substituteInPlace ./pysodium/__init__.py \
      --replace "ctypes.util.find_library('sodium') or ctypes.util.find_library('libsodium')" "'${libsodium}/lib/libsodium${soext}'"
  '';

  meta = with lib; {
    description =
      "A wrapper for libsodium providing high level crypto primitives ";
    homepage = "https://github.com/stef/pysodium";
    license = licenses.bsd2;
  };
}
