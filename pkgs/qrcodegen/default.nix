{ pkgs, version, src, buildPythonPackage }:
with pkgs;
buildPythonPackage {
  pname = "qrcodegen";
  inherit version src;

  sourceRoot = "source/python";
}
