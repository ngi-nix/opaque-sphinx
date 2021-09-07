{ pkgs, version, src }:
with pkgs;
stdenv.mkDerivation {
  pname = "equihash";
  inherit version src;

  buildInputs = [ libsodium ];

  postPatch = ''
    substituteInPlace Makefile \
      --replace "PREFIX?=/usr/local" "PREFIX=$out"
  '';

  installPhase = ''
    mkdir -p $out/{include,lib,src}

    cp -r $src/* $out/src

    make install
  '';
}
