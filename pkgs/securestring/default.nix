{ version, src, buildPythonPackage, openssl }:

buildPythonPackage rec {
  pname = "securestring";
  inherit src version;

  buildInputs = [ openssl ];
}
