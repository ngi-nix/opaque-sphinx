{ version, src, buildPythonPackage }:

buildPythonPackage {
  name = "qrcodegen";
  inherit version src;
  sourceRoot = "source/python";
}
