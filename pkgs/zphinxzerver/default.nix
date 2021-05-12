{ pkgs, version, src, bearssl-src, libsphinx-src, zigtoml-src }:
with pkgs;
stdenv.mkDerivation {
  name = "zphinxzerver-${version}";
  inherit version src;

  buildInputs = [ zig libsodium.dev rename ];

  patches = [ ./build.zig.patch ];

  postPatch = ''
    substituteInPlace ./sodium.h \
      --replace '"/usr/' '"/${libsodium.dev}/'
  '';

  #dontConfigure = true;

  buildPhase = ''
    # Do not use the git submodules.
    rm -rf BearSSL sphinx zig-toml
    cp -r ${bearssl-src} ./BearSSL
    cp -r ${libsphinx-src} ./sphinx
    cp -r ${zigtoml-src} ./zig-toml

    # https://github.com/ziglang/zig/issues/6810
    export XDG_CACHE_HOME=.

    zig build install --prefix ./build -Drelease-safe=true

    # Prefix binaries.
    (cd ./build/bin; rename -v 's/^/zphinxzerver-/' *)
  '';

  installPhase = ''
    cp -r ./build $out
  '';
}
