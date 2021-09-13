{ pkgs, version, src, buildPythonPackage }:
with pkgs;
buildPythonPackage rec {
  pname = "securestring";
  inherit src version;

  buildInputs = [ openssl ];
}
