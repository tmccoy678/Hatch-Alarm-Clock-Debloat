# Hatch Alarm Clock Debloat

Why does it take 45 seconds to change the color and sound from my Hatch alarm clock? This must be fixed before it drives me more insane than I already am. 

Anyways, I was frustrated with the fact that my mom bought me a $250 alarm clock that took like, five minutes to load so that I could change one light setting. I also reject the premise that a $250 alarm clock requires a paid subscription in order to be usable. 

I had grand dreams for this app and debloat, including the ability to use my own iPhone music library to listen to music from the giant speaker that the Hatch has. However, the bridge from the Hatch through bluetooth to my Flint2 router and then to my iPhone in order to "get around" Hatch not having native AirPlay features has not ever worked for me-- as in, I have been able to connect the Hatch as a speaker from my iPhone music library, but no music will play. I am considering that this is an artifact of iOS's excellence in music encryption, which I think I turned on at some point. This was all much easier when we just used limewire or frostwire. Anyways, if someone would like to discuss the fix for this, please email me: tmccoy678@gmail.com. 

I hope this repo provides someone a faster UI experience with their Hatch alarm clock. 

Thank you, 

Taylor 

Hatch Alarm Clock Debloat provides Rose Control, a local-first iPhone
controller for the Hatch Restore 2. The app connects directly over Bluetooth,
requires no Hatch account, remembers the paired clock, and reconnects
automatically during ordinary use.

## Supported path

| Part | Current support |
| --- | --- |
| Alarm clock | Hatch Restore 2 |
| Phone | iPhone running iOS 17 or newer |
| Build computer | Mac with Xcode and Swift |
| Daily connection | Direct Bluetooth Low Energy with automatic reconnection |
| Hatch account | Not used or requested |
| Distribution | Built and signed locally for the owner's iPhone |

The first installation requires Apple signing, iPhone Developer Mode, and one
Bluetooth pairing. The Restore's Bluetooth button may be needed for that first
pairing. After Rose Control reaches the dashboard, it saves the Restore's Core
Bluetooth identity in the app's private storage. Later launches reconnect
without a Hatch login or another button press while the Bluetooth bond remains
present.

See [Pairing and everyday use](docs/PAIRING.md) for the complete first-run and
recovery paths.

## Install or renew Rose Control

Connect and unlock the iPhone, then run:

```sh
./install --check
./install
```

The guided installer tests the source, builds and signs Rose Control, installs
it without launching it, and saves the private reinstall settings outside the
repository. Running the installer again with the same bundle identifier renews
an expired development-signed copy while preserving the app container.

The installer does not contact the clock or change its light, sound, time,
alarms, network, or firmware. Opening Rose Control establishes the Bluetooth
connection without sending a clock command. A control command is sent only
after the owner chooses an action in the app.

Detailed requirements and troubleshooting are in
[Installation](docs/INSTALLATION.md), [Compatibility](docs/COMPATIBILITY.md),
[Recovery](docs/RECOVERY.md), [Support](SUPPORT.md), and the
[Changelog](CHANGELOG.md).

## Controller capabilities

- Local light, color, brightness, volume, and sound controls.
- A bundled catalog of identified Restore 2 sounds.
- Local construction and delivery of alarm documents.
- Direct radio URLs and an optional owner-operated LAN audio relay.
- Native display-command and light-scene research tools.
- Automatic recovery of the remembered Bluetooth connection.

## Verified behavior

- Direct BLE light, color, brightness, volume, stop, included-sound, and alarm
  commands received device acknowledgements.
- Automatic reconnection was physically verified after terminating and
  relaunching the iPhone app without another Restore button press.
- The Swift package passes 37 tests, the firmware image builder passes four
  focused image-integrity tests, and the installer passes three tests.
- Native display-text and display-animation commands received transport-level
  acknowledgements.

Visible display output remains pending physical acceptance. Direct radio and
LAN relay playback remain pending audible acceptance. Current evidence and
remaining work are recorded in [Engineering status](STATUS.md).

## Privacy

Rose Control contains no Hatch login, analytics SDK, advertising SDK, or
telemetry client. The app stores the remembered peripheral identifier and local
preferences on the iPhone. The installer stores Apple signing choices, the
selected iPhone identifier, and the optional relay URL in an owner-only file on
the Mac. [Privacy](PRIVACY.md) documents the exact storage and network paths.

## Firmware research boundary

The repository also contains a research-only firmware patch builder pinned to
the source image whose SHA-256 is:

```text
7339e11f8193db6180443b37a6a09f68c427404a931f28b54ff00380d90e23aa
```

The iPhone installer does not read, build, or write firmware. The prepared
patched image has not been flashed. Firmware work requires identified
programming connections, eFuse security inspection, complete verified flash
dumps, and a proven restoration path for both ESP32 modules.

No vendor firmware image, device dump, credential, MAC address, private relay
URL, or maintenance key is stored in this repository.

## Repository layout

| Path | Purpose |
| --- | --- |
| `install` | Guided local iPhone build, signing, installation, and renewal |
| `ios/RoseControl` | Rose Control iPhone application |
| `ios/RoseControlCore` | Tested BLE protocol, alarm, display, sound, and light-scene code |
| `firmware/patch_local_rdl` | Exact-source research patch builder; never invoked by the installer |
| `router/rose-relay` | Optional owner-operated OpenWrt audio relay |

## Build and verification

```sh
cd ios/RoseControlCore
swift test

cd ../..
python3 -m unittest firmware.tests.test_esp32_image -v
python3 -m unittest discover -s tests -v

xcodebuild -project ios/RoseControl/RoseControl.xcodeproj \
  -scheme RoseControl \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Created by Taylor McCoy with Aster and other OpenAI Codex agents. Original
project code is available under the [MIT License](LICENSE). Hatch, Apple,
third-party software, firmware, trademarks, and platform components retain
their own terms. This is an independent interoperability and device-owner
research project and is not affiliated with Hatch.
