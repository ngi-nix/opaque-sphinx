{ pkgs, buildPythonPackage, src, version, libsphinx, pysodium, securestring }:
with pkgs;

buildPythonPackage rec {
  pname = "pwdsphinx";
  inherit src version;

  propagatedBuildInputs = [ libsphinx pysodium securestring ];

  postPatch = let soext = stdenv.hostPlatform.extensions.sharedLibrary;
  in ''
    substituteInPlace pwdsphinx/sphinxlib.py \
      --replace "ctypes.util.find_library('sphinx') or ctypes.util.find_library('libsphinx')" "'${libsphinx}/lib/libsphinx${soext}'"

    substituteInPlace pwdsphinx/sphinx.py \
      --replace "def main(params):" "def main(params=sys.argv):"
  '';

  # todo: add checks with self-signed cert
  doCheck = false;
}
