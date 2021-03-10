{
  description = "(insert short project description here)";

  # nixpkgs-unstable-2021-01-27
  inputs.nixpkgs = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    ref = "652b2d6dba246abd696bc6f2cb8b30032ed4fb56";
  };

  inputs.androsphinx-src = {
    type = "github";
    owner = "dnet";
    repo = "androsphinx";
    rev = "0bf34e1a4ff6a8c2dbb9c66c64b2f7381cef173f";
    flake = false;
  };

  inputs.libsphinx-src = {
    type = "github";
    owner = "stef";
    repo = "libsphinx";
    rev = "51b0c18c94b645bd7ea3bb21aef623318e0b7939";
    # sha256 = "1nk8d14n9i640b0c86ajm1i181xfg203s823b9jd5gx5y7ycpslg";
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

  outputs =
    { self, nixpkgs, androsphinx-src, libsphinx-src, hello-src, gnulib-src }:
    let

      # Generate a user-friendly version numer.
      version = builtins.substring 0 8 hello-src.lastModifiedDate;

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

          libsodium-src = libsodium.src;
          androidSystem = androidSystemByNixSystem.${system};
          buildGradle = callPackage ./gradle-env.nix { };

          androsphinxCryptoLibs = stdenvNoCC.mkDerivation {
            name = "androsphinxCryptoLibs";
            src = androsphinx-src;
            buildInputs = [ pkgconf ];

            patches = [ ./build-libsphinx.sh.patch ];

            dontConfigure = true;

            buildPhase = ''
              export ANDROID_NDK_HOME=${ndk}/libexec/android-sdk/ndk-bundle
              export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${androidSystem}/bin:$PATH
              rm -rf libsodium libsphinx
              tar -xzf ${libsodium-src} && mv ./libsodium-* libsodium
              cp -r ${libsphinx-src} ./libsphinx
              chmod -R +w ./libsphinx
              sh ./build-libsphinx.sh
            '';
            # todo: no shrink executables?

            installPhase = ''
              mkdir $out
              cp -r app/src/main/jniLibs $out
              ls -alh $out
            '';
          };
          # gradle tasks:
          # check - Runs all checks.
          # test - Run unit tests for all variants.
          # testDebugUnitTest - Run unit tests for the debug build.
          # testReleaseUnitTest - Run unit tests for the release build.
          androsphinx = buildGradle {
            envSpec = ./gradle-env.json;

            src = androsphinx-src;

            preBuild = ''
              # Copy previously compiled *.so files to make them available in the app.
              cp -r ${androsphinxCryptoLibs}/jniLibs app/src/main/

              # Make gradle aware of Android SDK.
              # See https://github.com/tadfisher/gradle2nix/issues/13
              echo "sdk.dir = ${sdk.androidsdk}/libexec/android-sdk" > local.properties
              printf "\nandroid.aapt2FromMavenOverride=${sdk.androidsdk}/libexec/android-sdk/build-tools/29.0.3/aapt2" >> gradle.properties
            '';

            #gradleFlags = [ "check" "test"];
            gradleFlags = [ "build" ];

            installPhase = ''
              mkdir -p $out
              ls -alR app/build
              # cp -r app/build/install/myproject $out
              find . -name '*.apk' -exec cp {} $out \;
            '';
          };
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

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) hello androsphinxCryptoLibs androsphinx;
      });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.hello);

      # A NixOS module, if applicable (e.g. if the package provides a system service).
      nixosModules.hello = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlay ];

        environment.systemPackages = [ pkgs.hello ];

        #systemd.services = { ... };
      };

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
