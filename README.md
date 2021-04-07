# Androsphinx

This flake packages the Android app [androsphinx](https://github.com/dnet/androsphinx) and some associated packages.

NGI Project pages:

* https://review.ngi-0.eu:2019/partner/project/2019-02-081
* https://nlnet.nl/project/OpaqueSphinxServer/index.html

The app is built on top of [libsphinx](https://github.com/stef/libsphinx/) (see the [readme](https://github.com/stef/libsphinx/#what-is-this-thing) for a good explanation of the library).

Briefly, the app allows you to communicate with a sphinx server (think "password server") to read & write credentials in a secure way.
The server never decrypts any passwords itself.
All encreption/decription is happening on the client side.

There is a reference Python sphinx client/server implementation called [pwdsphinx](https://github.com/stef/pwdsphinx) that is also packaged.
This allows to easily test the functionality of the Anrdoid app in a local network.

# Nix packages & their dependencies

Most of the packages below depend (indirectly) on [libsodium](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/libraries/libsodium/default.nix). The version shipped with Nix is used.

* [libsphinx](https://github.com/stef/libsphinx/): "a cryptographic password storage"; a C library and some standalone tools.
  * Dependencies: libsodium
* [pysodium](https://github.com/stef/pysodium): "a very simple wrapper around libsodium masquerading as nacl"; a Python library
  * Dependencies: libsodium
* [securestring](https://github.com/dnet/pysecstr): a Python library to clear "the contents of strings containing cryptographic material"
* [qrcodegen](https://github.com/nayuki/QR-Code-generator): a QR Code generator library for multiple languages
* [pwdsphinx](https://github.com/stef/pwdsphinx): Python bindings for libsphinx.
  * Dependencies: libsphinx, pysodium, securestring, qrcodegen
* [androsphinx](https://github.com/dnet/androsphinx): an Android app wrapping libsphinx.
  * Dependencies: libsodium, libsphinx

Note: The androsphinx readme suggests to use ``qrencode`` to generate a QR code that is used to configure the phone. Similarly, pwdsphinx' readme suggests ``qrcodegen``.
These tools fulfill the same task.

Strictly speaking, this Flake packages more than needed.
The additional packages (``pwdsphinx`` & its upstream dependencies) allows to easily test the Android app.

# Local test setup

You need:

* a development machine running Linux
* an Android phone
* a local (wireless) network where both the phone & the dev machine can talk to each other
* [Nix](https://nixos.org/) (surprise!) with [Flakes](https://nixos.wiki/wiki/Flakes) support.

The setup is as follows:
A sphinx server ("oracle") will run on the dev machine.
A sphinx command line client will run independently on the dev machine and connect to the oracle.
The androsphinx app will also connect (via the local network) to the oracle.
Both clients (cli & app) will be able to access the same credentials.

## Server setup

```bash
# Install & activate all dependencies.
$ nix develop
# Go to the test folder.
$ rm -rf ~/sphinx-test ; mkdir ~/sphinx-test && cd ~/sphinx-test

# Create an SSL certificate (only do this once).
$ openssl req -nodes -x509 -sha256 -newkey rsa:4096 -keyout ssl_key.pem -out ssl_cert.pem -days 365 -batch
$ ls ssl_cert.pem ssl_key.pem # make sure these files exist.

# Setup the server configuration.
$ cat <<EOF > sphinx.cfg
[server]
verbose = True
address = 0.0.0.0
port = 2355
datadir = ~/sphinx-test/datadir
ssl_key = ~/sphinx-test/ssl_key.pem
ssl_cert = ~/sphinx-test/ssl_cert.pem
EOF

# Run the server
$ oracle # do not kill this process
```

## CLI client setup

Setup the client in a new terminal.

```bash
# Install & activate all dependencies.
$ nix develop
# Go to the test folder.
$ cd ~/sphinx-test

# Setup the client configuration.
# Note: For a more realistic scenarion, replache 127.0.0.1 by the actual IP
# address of the localhost. Also note that the same cfg file (see above) is used.
$ cat <<EOF >> sphinx.cfg # append to the cfg file
[client]
verbose = True
address = 127.0.0.1
port = 2355
datadir = ~/sphinx-test/datadir
ssl_key = ~/sphinx-test/ssl_key.pem
ssl_cert = ~/sphinx-test/ssl_cert.pem
EOF

# Generate the master key that is used to derive secrets. This key must be
# shared among clients.
$ sphinx init
$ ls ./datadir/masterkey

# Store credentials. You should see log output from the oracle server and the
# client should return a password.
# See https://github.com/stef/pwdsphinx#create-password for details.
$ printf 'm' | sphinx create user site uld 10 # "m" is the master password
<password>

# Retrieve credentials.
printf 'm' | sphinx get user site
<password>
printf 'wrongmasterpassword' | sphinx get user site
<some-other-password>
```

## Android client setup

Connect your phone to the development machine and make sure the 'Developer options' are enabled.

Open a 3rd terminal.

```bash
# Install & activate all dependencies.
$ nix develop
# Go to the test folder.
$ cd ~/sphinx-test

# Check that your phone is accessible.
$ adb devices

# Install the custom SSL certificate.
adb push ssl_cert.pem mnt/sdcard/ssl_cert.pem # or wherever else you can upload to the phone

# In your phone, open Settings -> Security -> "Install [certificates] from
# device memory/SD card" (or similar) -> Choose the certificate file and install
# it.

# Install the app. (The 'uninstall' command will fail at the first time, of
# course).
$ ls $DEBUG_APK # see flake.nix
$ adb uninstall org.hsbp.androsphinx ; adb install $DEBUG_APK

# At this point, you can unplug the phone. Make sure it is connected to the
# local network instead. Also, get the dev machine's IP address.
$ ip a
$ export IP_ADDR=X.X.X.X # 192.168....

# Launch the androsphinx app in the phone, press the 'Settings' icon and press 'Scan from
# QR code'. Generate the QR code on the dev machine (make sure the $IP_ADDR is set).
(printf '\x01' ; cat ./datadir/masterkey ; printf '\x09\x33%s' "$IP_ADDR") | qrencode -8 -t ANSI256
# (Now scan the generated code with the phone.)
```

The phone is now configured correctly.
Make sure the server process (``oracle``) is running.
Use the app's search form to search for "site".
You should see a log statement from the sphinx server as well as the entry "user" on the phone.
Try copying the password to the clipboard by using the master password from above.
You should receive the same password as the CLI client.

# See also

* https://github.com/NixOS/nixpkgs/pull/115229

* https://github.com/stef/libsphinx/pull/8

* https://github.com/stef/pwdsphinx/issues/9
* https://github.com/stef/pwdsphinx/issues/10
* https://github.com/stef/pwdsphinx/issues/13
* https://github.com/stef/pwdsphinx/pull/14

* https://github.com/dnet/androsphinx/issues/8
* https://github.com/dnet/androsphinx/pull/5
