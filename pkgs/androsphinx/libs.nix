{ pkgs, version, src, libsodium-src, libsphinx-src, ndk, androidSystem }:
with pkgs;
# Use stdenvNoCC to not make GCC interfere with the Android compilers.
stdenvNoCC.mkDerivation {
  name = "androsphinxCryptoLibs-${version}";
  inherit version src;

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

  # This derivation is actually not needed separately from androsphinx. The
  # library files could be compiled before compiling (gradle) the app.
  # However, for debugging & rebuilding, it is quite convenient to build the
  # libraries separately.
  installPhase = ''
    mkdir $out
    cp -r app/src/main/jniLibs $out
  '';
}
