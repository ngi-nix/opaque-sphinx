{ pkgs, version, src, buildPythonPackage, equihash }:
with pkgs;
buildPythonPackage rec {
  pname = "pyequihash";
  inherit version src;

  sourceRoot = "source/python";

  postPatch = let soext = stdenv.hostPlatform.extensions.sharedLibrary;
  in ''
    substituteInPlace equihash/__init__.py \
      --replace "ctypes.util.find_library('equihash') or ctypes.util.find_library('libequihash')" "'${equihash}/lib/libequihash${soext}'"
  '';
}
