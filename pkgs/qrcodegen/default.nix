{ pkgs, version, src }:
with pkgs;
buildPythonPackage {
  pname = "qrcodegen";
  inherit version src;

  sourceRoot = "source/python";
}
