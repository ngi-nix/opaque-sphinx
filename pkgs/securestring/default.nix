{ pkgs, version, src }:
with pkgs;
buildPythonPackage rec {
  pname = "securestring";
  inherit src version;

  buildInputs = [ openssl ];
}
