{ pkgs, version, src, libsphinx, pyequihash, pysodium, securestring, qrcodegen
, zxcvbn }:
with pkgs;
# todo: rename oracle (ando ther binaries?)
buildPythonPackage rec {
  pname = "pwdsphinx";
  inherit src version;

  propagatedBuildInputs =
    [ libsphinx pyequihash pysodium securestring qrcodegen zxcvbn ];

  postPatch = let soext = stdenv.hostPlatform.extensions.sharedLibrary;
  in ''
    substituteInPlace pwdsphinx/sphinxlib.py \
      --replace "ctypes.util.find_library('sphinx') or ctypes.util.find_library('libsphinx')" "'${libsphinx}/lib/libsphinx${soext}'"

    substituteInPlace setup.py \
      --replace "zxcvbn-python" "zxcvbn"
  '';

  checkInputs = [ crudini ];
  preCheck = ''
    # Prepare the expected config file for the tests.
    FILE=sphinx.cfg
    cp sphinx.cfg_sample $FILE
    # Some settings are commented out but must be activated.
    # "# address=..." -> "address=..."
    for PREFIX in address timeout ; do
      sed -i "s/^#[[:space:]]*$PREFIX=/$PREFIX=/" $FILE
    done
  '';
}
