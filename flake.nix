{
  description = "Androsphinx - a SPHINX app for Android.";

  inputs.nixpkgs = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    ref = "3cadb8b32209d13714b53317ca96ccbd943b6e45";
  };

  inputs.securestring-src = {
    type = "github";
    owner = "dnet";
    repo = "pysecstr";
    rev = "5d143cffd144378e8d50710de6bc05659f8645fd";
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
  inputs.androsphinx-src = {
    type = "github";
    owner = "dnet";
    repo = "androsphinx";
    rev = "afcab7478357904d323a70a87d2037f7f56fb2f9";
    flake = false;
  };
  inputs.libsphinx-src = {
    type = "github";
    owner = "stef";
    repo = "libsphinx";
    rev = "51b0c18c94b645bd7ea3bb21aef623318e0b7939";
    flake = false;
  };
  inputs.pwdsphinx-src = {
    type = "github";
    owner = "stef";
    repo = "pwdsphinx";
    rev = "f7acc8c9f4e01d44ff3ad65d50e96be337741584";
    flake = false;
  };

  outputs = { self, nixpkgs, securestring-src, pysodium-src, androsphinx-src
    , libsphinx-src, pwdsphinx-src, qrcodegen-src }:
    let

      getVersion = input: builtins.substring 0 7 input.rev;
      securestring-version = getVersion securestring-src;
      pysodium-version = getVersion pysodium-src;
      pwdsphinx-version = getVersion pwdsphinx-src;
      libsphinx-version = getVersion libsphinx-src;
      qrcodegen-version = getVersion qrcodegen-src;
      androsphinx-version = getVersion androsphinx-src;

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
            zxcvbn = zxcvbn;
            qrcodegen = qrcodegen;
          };

          androsphinxCryptoLibs = callPackage ./pkgs/androsphinx/libs.nix {
            version = androsphinx-version;
            src = androsphinx-src;
            androidSystem = androidSystemByNixSystem.${system};
            inherit libsphinx-src;
          };
          androsphinx = callPackage ./pkgs/androsphinx {
            version = androsphinx-version;
            src = androsphinx-src;
          };
        };

      # Provide a nix-shell env to work with.
      devShell = forAllSystems (system:
        with nixpkgsFor.${system};
        mkShell {
          buildInputs =
            [ pwdsphinx openssl sdk.androidsdk androsphinx qrencode ];
          shellHook = ''
            export DEBUG_APK=${androsphinx}/app-debug.apk
          '';
        });

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) pwdsphinx androsphinx libsphinx;
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
                -keyout ssl_key.pem -out ssl_cert.pem -days 365 -batch
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

              # Kill the server.
              kill %1
            '';

            installPhase = ''
              mkdir $out
            '';

          };
      });

    };
}
