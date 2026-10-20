# Hatch Alarm Clock Debloat

Hatch Alarm Clock Debloat is a local-first controller and firmware research project for a Hatch Restore 2. It preserves the light, display, speaker, physical controls, independent alarms, included sounds, selected internet radio, and optional LAN audio while removing routine dependence on a Hatch login and cloud-control path.

The project contains:

- an iPhone controller that speaks directly to the Restore 2 over BLE;
- a reusable Swift package for UART commands, framed JSON, sound control, alarm construction, display commands, and light scenes;
- a restricted macOS BLE probe for reversible diagnostics;
- a narrowly pinned firmware patch builder that routes local alarm documents through the device's existing full-RDL parser and omits creation of the Hatch IoT task; and
- an optional OpenWrt AirPlay-to-MP3 relay for owner-selected local audio.

## Verified behavior

- Direct BLE light, color, brightness, volume, stop, included-sound, and alarm commands receive device acknowledgements.
- The app bundles the verified free-sound catalog and constructs a native alarm document locally.
- The factory `WSL` command provides a temporary IoT disconnect while factory firmware remains installed.
- Native display-text and display-animation commands transport successfully over BLE.
- The Swift package passes 37 tests; the firmware image builder passes four focused image-integrity tests.

The display commands have transport-level confirmation but still need visible physical-display acceptance. Direct radio and LAN audio paths also retain explicit audible-acceptance checks.

## Recovery boundary

The firmware builder targets only the source image whose SHA-256 is:

```text
7339e11f8193db6180443b37a6a09f68c427404a931f28b54ff00380d90e23aa
```

No vendor firmware image, device dump, credential, MAC address, or maintenance key is stored here. The prepared patched image has not been flashed. Before writing either ESP32, identify both programming connections, inspect eFuse security state, obtain complete verified flash dumps, and prove the restore path. A factory reset cannot recreate erased firmware.

## Build and verification

```sh
cd ios/RoseControlCore
swift test

cd ../..
python3 -m unittest firmware.tests.test_esp32_image -v

xcodebuild -project ios/RoseControl/RoseControl.xcodeproj \
  -scheme RoseControl \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The optional relay configuration lives under `router/rose-relay`. Its LAN endpoint is deployment-specific and should be changed in the app before use on another network.

Created by Taylor McCoy with Aster and other OpenAI Codex agents.

This private repository has no public license yet. Licensing and a final hardware/privacy review should precede public release.
