{ src, androsphinxCryptoLibs, sdk, callPackage }:
let buildGradle = callPackage ./gradle-env.nix { };
in buildGradle {
  # todo: add version
  envSpec = ./gradle-env.json;

  inherit src;

  preBuild = ''
    # Copy previously compiled *.so files to make them available in the app.
    cp -r ${androsphinxCryptoLibs}/jniLibs app/src/main/

    # Make gradle aware of Android SDK.
    # See https://github.com/tadfisher/gradle2nix/issues/13
    echo "sdk.dir = ${sdk.androidsdk}/libexec/android-sdk" > local.properties
    printf "\nandroid.aapt2FromMavenOverride=${sdk.androidsdk}/libexec/android-sdk/build-tools/29.0.3/aapt2" >> gradle.properties
  '';

  #gradleFlags = [ "check" "test" ];
  gradleFlags = [ "build" ];

  installPhase = ''
    mkdir -p $out
    ls -alR app/build
    # cp -r app/build/install/myproject $out
    find . -name '*.apk' -exec cp {} $out \;
  '';
}
