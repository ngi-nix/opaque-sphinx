{
  description = "(insert short project description here)";

  # nixpkgs-unstable-2021-01-27
  inputs.nixpkgs = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    ref = "652b2d6dba246abd696bc6f2cb8b30032ed4fb56";
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
    rev = "c29b9a259c21122dadb4e608d9d8aac8d8bc8a85";
    flake = false;
  };

  # Upstream source tree(s).
  inputs.hello-src = {
    url = "git+https://git.savannah.gnu.org/git/hello.git";
    flake = false;
  };
  inputs.gnulib-src = {
    url = "git+https://git.savannah.gnu.org/git/gnulib.git";
    flake = false;
  };

  outputs = { self, nixpkgs, securestring-src, pysodium-src, androsphinx-src
    , libsphinx-src, pwdsphinx-src, qrcodegen-src, hello-src, gnulib-src }:
    let

      getVersion = input: builtins.substring 0 7 input.rev;
      version =
        builtins.substring 0 8 hello-src.lastModifiedDate; # todo: remove
      securestring-version = getVersion securestring-src;
      pysodium-version = getVersion pysodium-src;
      pwdsphinx-version = getVersion pwdsphinx-src;
      libsphinx-version = getVersion libsphinx-src;
      qrcodegen-version = getVersion qrcodegen-src;
      androsphinx-version = getVersion androsphinx-src;

      # System types to support.
      supportedSystems = [ "x86_64-linux" ];

      # Mapping from Nix' "system" to Android's "system".
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
            abiVersions =
              [ "x86" "x86_64" "armeabi-v7a" "armeabi-v8a" ]; # todo: v8a
            includeNDK = true;
            ndkVersion = "22.0.7026061";
          };
          # Todo: use nixpkgs with merged PR:
          # https://github.com/NixOS/nixpkgs/pull/115229
          # and replace ndk by snd.ndk-bundle;
          ndk = sdk.ndk-bundle.overrideAttrs (oldAttrs: rec {
            postPatch =
              "sed -i 's|#!/bin/bash|#!${pkgs.bash}/bin/bash|' $(pwd)/build/tools/make_standalone_toolchain.py ";
          });

          buildPythonPackage = python3.pkgs.buildPythonPackage;
          zxcvbn = python3.pkgs.zxcvbn;
          androidSystem = androidSystemByNixSystem.${system};
          buildGradle = callPackage ./gradle-env.nix { };

          libsodium-src = libsodium.src;
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
            inherit libsphinx-src;
          };
          #androsphinxCryptoLibs' = stdenvNoCC.mkDerivation {
          #  name = "androsphinxCryptoLibs";
          #  src = androsphinx-src;
          #  buildInputs = [ pkgconf ];

          #  patches = [ ./build-libsphinx.sh.patch ];

          #  dontConfigure = true;

          #  buildPhase = ''
          #    export ANDROID_NDK_HOME=${ndk}/libexec/android-sdk/ndk-bundle
          #    export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${androidSystem}/bin:$PATH
          #    # Do not use the git submodules.
          #    rm -rf libsodium libsphinx
          #    tar -xzf ${libsodium-src} && mv ./libsodium-* libsodium
          #    cp -r ${libsphinx-src} ./libsphinx
          #    chmod -R +w ./libsphinx
          #    sh ./build-libsphinx.sh
          #  '';

          #  installPhase = ''
          #    mkdir $out
          #    cp -r app/src/main/jniLibs $out
          #    ls -alh $out
          #  '';
          #};
          # gradle tasks:
          # check - Runs all checks.
          # test - Run unit tests for all variants.
          # testDebugUnitTest - Run unit tests for the debug build.
          # testReleaseUnitTest - Run unit tests for the release build.
          androsphinx =
            callPackage ./pkgs/androsphinx { src = androsphinx-src; };

          hello = with final;
            stdenv.mkDerivation rec {
              name = "hello-${version}";

              src = hello-src;

              buildInputs = [
                androsphinxCryptoLibs
                autoconf
                automake
                gettext
                gnulib
                perl
                gperf
                texinfo
                help2man
              ];

              preConfigure = ''
                mkdir -p .git # force BUILD_FROM_GIT
                ./bootstrap --gnulib-srcdir=${gnulib-src} --no-git --skip-po
              '';

              meta = {
                homepage = "https://www.gnu.org/software/hello/";
                description = "A program to show a familiar, friendly greeting";
              };
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

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage =
        forAllSystems (system: self.packages.${system}.androsphinx);

      ## A NixOS module, if applicable (e.g. if the package provides a system service).
      #nixosModules.hello = { pkgs, ... }: {
      #  nixpkgs.overlays = [ self.overlay ];

      #  environment.systemPackages = [ pkgs.hello ];

      #  #systemd.services = { ... };
      #};

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems (system: {
        inherit (self.packages.${system}) hello;

        # Additional tests, if applicable.
        test = with nixpkgsFor.${system};
          stdenv.mkDerivation {
            name = "hello-test-${version}";

            buildInputs = [ hello ];

            unpackPhase = "true";

            buildPhase = ''
              echo 'running some integration tests'
              [[ $(hello) = 'Hello, world!' ]]
            '';

            installPhase = "mkdir -p $out";
          };

        # A VM test of the NixOS module.
        vmTest = with import (nixpkgs + "/nixos/lib/testing-python.nix") {
          inherit system;
        };

          makeTest {
            nodes = {
              client = { ... }: { imports = [ self.nixosModules.hello ]; };
            };

            testScript = ''
              start_all()
              client.wait_for_unit("multi-user.target")
              client.succeed("hello")
            '';
          };
      });

    };
}
