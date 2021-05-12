{ pkgs, version, src, libsphinx, pysodium, securestring, qrcodegen, zxcvbn }:
with pkgs;
# todo: rename oracle (ando ther binaries?)
buildPythonPackage rec {
  pname = "pwdsphinx";
  inherit src version;

  propagatedBuildInputs = [ libsphinx pysodium securestring qrcodegen zxcvbn ];

  postPatch = let soext = stdenv.hostPlatform.extensions.sharedLibrary;
  in ''
    substituteInPlace pwdsphinx/sphinxlib.py \
      --replace "ctypes.util.find_library('sphinx') or ctypes.util.find_library('libsphinx')" "'${libsphinx}/lib/libsphinx${soext}'"

    substituteInPlace setup.py \
      --replace "zxcvbn-python" "zxcvbn"
  '';

  checkInputs = [ crudini ];
  preCheck = ''
    # The checks try to read some values from the sphinx.cfg file but don't use
    # them. We can use some dummy values.
    FILE=sphinx.cfg
    cp sphinx.cfg_sample $FILE
    for SECTION in client server ; do
      for PREFIX in ssl_key ssl_cert ; do
        crudini --set $FILE $SECTION $PREFIX ./''${PREFIX}.doesnt-exist.pem
      done
    done
  '';
}
