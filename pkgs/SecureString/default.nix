{ buildPythonPackage, fetchPypi, openssl }:

buildPythonPackage rec {
  pname = "SecureString";
  version = "0.2";

  buildInputs = [ openssl ];

  src = fetchPypi {
    inherit pname version;
    sha256 = "119x40m9xg685xrc2k1qq1wkf36ig7dy48ln3ypiqws1r50z6ck4";
  };
}
