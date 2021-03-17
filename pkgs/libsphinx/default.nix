{ pkgs, src, version }:
with pkgs;
let standaloneBinaries = "2pass challenge respond derive";
in stdenv.mkDerivation {
  inherit src version;
  name = "libsphinx-${version}";
  buildInputs = [ pkgconf libsodium ];

  buildPhase = ''
    cd src
    make
    # Make sure the library can be found correctly by other programs
    # by setting a soname (which is not done during compile time).
    patchelf --set-soname libsphinx.so libsphinx.so
    cd -
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib,src}

    cp -r $src/* $out/src

    cp src/libsphinx.so $out/lib

    for f in ${standaloneBinaries} ; do
      cp src/bin/$f $out/bin/$f
    done
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    cp src/bin/tests/test.sh .
    for f in ${standaloneBinaries} ; do
      substituteInPlace ./test.sh \
       --replace "../$f" "$out/bin/$f"
    done
    ./test.sh
  '';

}
