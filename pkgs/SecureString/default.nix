{ version, sha256, buildPythonPackage, fetchPypi, openssl }:

buildPythonPackage rec {
  pname = "SecureString";
  inherit version sha256;

  buildInputs = [ openssl ];

  src = fetchPypi { inherit pname version sha256; };
}
