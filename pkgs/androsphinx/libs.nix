{ version, src, libsodiumSrc, libsphinxSrc, stdenv, pkgconf, ndk, androidSystem }:

stdenvNoCC.mkDerivation {
  name = "androsphinxCryptoLibs-${version}";
  src = src
  buildInputs = [ pkgconf ];

  patches = [ ./build-libsphinx.sh.patch ];

  dontConfigure = true;

  buildPhase = ''
    export ANDROID_NDK_HOME=${ndk}/libexec/android-sdk/ndk-bundle
    export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${androidSystem}/bin:$PATH
    # Do not use the git submodules.
    rm -rf libsodium libsphinx
    tar -xzf ${libsodium-src} && mv ./libsodium-* libsodium
    cp -r ${libsphinx-src} ./libsphinx
    chmod -R +w ./libsphinx
    sh ./build-libsphinx.sh
  '';

  installPhase = ''
    mkdir $out
    cp -r app/src/main/jniLibs $out
    ls -alh $out
  '';
}
