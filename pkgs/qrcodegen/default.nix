{ pkgs, version, src }:
with pkgs;
buildPythonPackage {
  name = "qrcodegen";
  inherit version src;
  sourceRoot = "source/python";
}
