{
  # tood: equihash
  description =
    "SPHINX - A password Store that Perfectly Hides from Itself (No Xaggeration)";

  inputs.androsphinx-src = {
    type = "github";
    owner = "dnet";
    repo = "androsphinx";
    rev = "afcab7478357904d323a70a87d2037f7f56fb2f9";
    flake = false;
  };
  inputs.bearssl-src = {
    url = "git+https://www.bearssl.org/git/BearSSL";
    flake = false;
  };
  inputs.equihash-src = {
    type = "github";
    owner = "stef";
    repo = "equihash";
    rev = "d4657dcb588ae852f8ab5c777837b0578caa3ffb";
    flake = false;
  };
  inputs.libsphinx-src = {
    type = "github";
    owner = "stef";
    repo = "libsphinx";
    rev = "51b0c18c94b645bd7ea3bb21aef623318e0b7939";
    flake = false;
  };
  inputs.nixpkgs = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    ref = "3cadb8b32209d13714b53317ca96ccbd943b6e45";
  };
  inputs.pwdsphinx-src = {
    type = "github";
    owner = "stef";
    repo = "pwdsphinx";
    rev = "f7acc8c9f4e01d44ff3ad65d50e96be337741584";
    flake = false;
  };
  inputs.pysodium-src = {
    type = "github";
    owner = "stef";
    repo = "pysodium";
    rev = "3ffe86a4a2c731a993daac4dc142827201519f03";
    flake = false;
  };
  inputs.qrcodegen-src = {
    type = "github";
    owner = "nayuki";
    repo = "QR-Code-generator";
    rev = "71c75cfeb0f06788ebc43a39b704c39fcf5eba7c";
    flake = false;
  };
  inputs.securestring-src = {
    type = "github";
    owner = "dnet";
    repo = "pysecstr";
    rev = "5d143cffd144378e8d50710de6bc05659f8645fd";
    flake = false;
  };
  inputs.zigtoml-src = {
    type = "github";
    owner = "aeronavery";
    repo = "zig-toml";
    rev = "299e2d9f87816a5ce374853e03f13176b821b81e";
    flake = false;
  };
  inputs.zphinxzerver-src = {
    type = "github";
    owner = "stef";
    repo = "zphinx-zerver";
    rev = "816dea4413e8f111fdf969abccce119ae4825bcc";
    flake = false;
  };

  outputs = { self, androsphinx-src, bearssl-src, equihash-src, libsphinx-src
    , nixpkgs, pwdsphinx-src, pysodium-src, qrcodegen-src, securestring-src
    , zigtoml-src, zphinxzerver-src }:
    let

      getVersion = input: builtins.substring 0 7 input.rev;
      androsphinx-version = getVersion androsphinx-src;
      equihash-version = getVersion equihash-src;
      libsphinx-version = getVersion libsphinx-src;
      pwdsphinx-version = getVersion pwdsphinx-src;
      pysodium-version = getVersion pysodium-src;
      qrcodegen-version = getVersion qrcodegen-src;
      securestring-version = getVersion securestring-src;
      zphinxzerver-version = getVersion zphinxzerver-src;

      # System types to support.
      supportedSystems = [ "x86_64-linux" ];

      # Mapping from Nix' "system" to Android's "system". The key corresponds
      # to the usual "system" variable content in Nix context. The value
      # corresponds to the same concept, however in Android context. See also
      # pkgs/development/androidndk-pkgs/androidndk-pkgs.nix. This is needed
      # here in order to pull the right binaries from the Android NDK when
      # building androsphinx.
      androidSystemByNixSystem = {
        "x86_64-linux" = "linux-x86_64";
        "x86_64-darwin" = "darwin-x86_64";
      };

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
          config.android_sdk.accept_license = true;
        });

    in {

      # A Nixpkgs overlay.
      overlay = final: prev:
        with final.pkgs; {

          sdk = pkgs.androidenv.composeAndroidPackages {
            buildToolsVersions = [ "28.0.3" "29.0.3" ];
            platformVersions = [ "29" ];
            abiVersions = [ "x86" "x86_64" "armeabi-v7a" "armeabi-v8a" ];
            includeNDK = true;
            ndkVersion = "22.0.7026061";
          };
          ndk = sdk.ndk-bundle;
          buildPythonPackage = python3.pkgs.buildPythonPackage;
          zxcvbn = python3.pkgs.zxcvbn;
          libsodium-src = libsodium.src; # use nixpkgs

          equihash = callPackage ./pkgs/equihash {
            version = equihash-version;
            src = equihash-src;
          };
          pyequihash = callPackage ./pkgs/equihash/pyequihash.nix {
            version = equihash-version;
            src = equihash-src;
            inherit equihash;
          };
          pysodium = callPackage ./pkgs/pysodium {
            version = pysodium-version;
            src = pysodium-src;
          };
          securestring = callPackage ./pkgs/securestring {
            version = securestring-version;
            src = securestring-src;
          };
          libsphinx = callPackage ./pkgs/libsphinx {
            version = libsphinx-version;
            src = libsphinx-src;
          };
          qrcodegen = callPackage ./pkgs/qrcodegen {
            version = qrcodegen-version;
            src = qrcodegen-src;
          };
          pwdsphinx = callPackage ./pkgs/pwdsphinx {
            version = pwdsphinx-version;
            src = pwdsphinx-src;
            inherit libsphinx pyequihash pysodium securestring qrcodegen zxcvbn;
          };

          androsphinxCryptoLibs = callPackage ./pkgs/androsphinx/libs.nix {
            version = androsphinx-version;
            src = androsphinx-src;
            inherit libsphinx-src libsodium-src ndk androidSystem;
          };
          androsphinx = callPackage ./pkgs/androsphinx {
            version = androsphinx-version;
            src = androsphinx-src;
          };

          zphinxzerver = callPackage ./pkgs/zphinxzerver {
            version = zphinxzerver-version;
            src = zphinxzerver-src;
            inherit bearssl-src equihash libsphinx-src zigtoml-src;
          };
        };

      # Provide a nix-shell env to work with.
      devShell = forAllSystems (system:
        with nixpkgsFor.${system};
        mkShell {
          buildInputs = [
            androsphinx
            openssl
            pwdsphinx
            qrencode
            sdk.androidsdk
            zphinxzerver
          ];
          shellHook = ''
            export DEBUG_APK=${androsphinx}/app-debug.apk
          '';
        });

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system})
          androsphinx equihash libsphinx pwdsphinx zphinxzerver;
      });

      defaultPackage =
        forAllSystems (system: self.packages.${system}.androsphinx);

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems (system: {

        androsphinxTest = with nixpkgsFor.${system};
          stdenv.mkDerivation {
            name = "androsphinx-test-${androsphinx-version}";

            dontUnpack = true;

            buildInputs = [ androsphinx unzip ];

            buildPhase = ''
              # Check that the apks are available.
              NUMBER_OF_GENERATED_APK_FILES=$(find ${androsphinx} -name '*.apk' -print | wc -l)
              NUMBER_OF_EXPECTED_APK_FILES=2 # debug + release
              if [[ "$NUMBER_OF_GENERATED_APK_FILES" != "$NUMBER_OF_EXPECTED_APK_FILES" ]] ; then
                echo "Could not find all expected *.apk files!"
                exit 1
              fi

              # Check that the apk contains the crypto libs.
              mkdir extracted
              cp ${androsphinx}/app-debug.apk ./extracted
              cd extracted
              unzip *.apk
              NUMBER_OF_SHIPPED_LIBRARY_FILES=$(ls -1 lib/*/{libsodium,libsphinx}.so | wc -l)
              NUMBER_OF_EXPECTED_LIBRARY_FILES=8 # 2 libs for each of the 4 archs
              if [[ "$NUMBER_OF_SHIPPED_LIBRARY_FILES" != "$NUMBER_OF_EXPECTED_LIBRARY_FILES" ]] ; then
                echo "Could not find all expected *.so files in the APK!"
                exit 1
              fi
            '';

            installPhase = ''
              mkdir $out
            '';
          };

        pwdsphinxTest = with nixpkgsFor.${system};
          stdenv.mkDerivation {
            name = "pwdsphinx-test-${pwdsphinx-version}";

            dontUnpack = true;

            buildInputs = [ pwdsphinx openssl ];

            buildPhase = ''
              # Create custom certificate.
              openssl req -nodes -x509 -sha256 -newkey rsa:4096 \
                -keyout ssl_key.pem -out ssl_cert.pem -batch
              ls ssl_cert.pem ssl_key.pem # make sure these files exist.

              # Configure client & server.
              cat <<EOF > sphinx.cfg
              [client]
              verbose = False
              address = 127.0.0.1
              port = 2355
              datadir = ./datadir
              ssl_key = ./ssl_key.pem
              ssl_cert = ./ssl_cert.pem

              [server]
              verbose = False
              address = 0.0.0.0
              port = 2355
              datadir = ./datadir
              ssl_key = ./ssl_key.pem
              ssl_cert = ./ssl_cert.pem
              EOF

              # Run server in background.
              oracle 2>&1 > oracle.log &

              # Access server.
              MASTER_PASSWORD="l@kjq34pseudorandomrjaop0Pq3y45980A;hdf"
              sphinx init
              printf $MASTER_PASSWORD | sphinx create user site uld 10 > password1
              printf $MASTER_PASSWORD | sphinx get user site > password2

              # Make sure the password can be retrieved.
              diff password1 password2
            '';

            installPhase = ''
              mkdir $out
            '';

          };
        zphinxzerverTest = with nixpkgsFor.${system};
          stdenv.mkDerivation {
            name = "zphinxzerver-test-${pwdsphinx-version}";

            dontUnpack = true;

            buildInputs = [ pwdsphinx zphinxzerver openssl ];

            buildPhase = ''
              # Create custom certificate.
              openssl ecparam -genkey -out ssl_key.pem -name secp384r1
              openssl req -nodes -x509 -sha256 -key ssl_key.pem \
                -out ssl_cert.pem -batch
              ls ssl_cert.pem ssl_key.pem # make sure these files exist.

              # Configure pwdsphinx client.
              mkdir client; cd client
              cat <<EOF > sphinx.cfg
              [client]
              verbose = true
              address = 127.0.0.1
              port = 2355
              datadir = ../datadir
              ssl_key = ../ssl_key.pem
              ssl_cert = ../ssl_cert.pem
              EOF
              cd -

              # Configure zphinxzerver. Currently, the same config file cannot
              # be used for both the Python and the Zig implementation. See
              # https://github.com/stef/zphinx-zerver/issues/1.
              mkdir server; cd server
              cat <<EOF > sphinx.cfg
              [server]
              verbose = true
              address = "127.0.0.1"
              port = 2355
              datadir = "../datadir"
              ssl_key = "../ssl_key.pem"
              ssl_cert = "../ssl_cert.pem"
              EOF
              cd -

              # Run zphinxzerver in background.
              cd server
              zphinxzerver-oracle 2>&1 > oracle.log &
              cd -

              # Access server through pwdsphinx client.
              cd client
              MASTER_PASSWORD="l@kjq34pseudorandomrjaop0Pq3y45980A;hdf"
              sphinx init
              printf $MASTER_PASSWORD | sphinx create user site uld 10 > password1
              printf $MASTER_PASSWORD | sphinx get user site > password2
              # Make sure the password can be retrieved.
              diff password1 password2
              cd -
            '';

            installPhase = ''
              mkdir $out
            '';
          };

      });

    };
}
