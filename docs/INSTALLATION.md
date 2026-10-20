# Installation

The installer builds and signs Rose Control for an owner's iPhone. It is also
the renewal path when iOS reports that a development-signed copy is no longer
available.

## Requirements

- a Mac with Xcode and the Swift toolchain;
- an Apple ID added in Xcode;
- an unlocked, trusted iPhone connected by USB or available through Xcode's
  paired-device connection; and
- Developer Mode enabled on the iPhone when required by iOS.

Developer Mode is a one-time iOS requirement for a locally signed app. The
first Restore connection may also require holding the clock's Bluetooth button
to establish the phone's bond. Rose Control then remembers that Restore locally
and reconnects without a Hatch login or another button press while the bond
remains present.

## Run

```sh
./install --check
./install
```

The check lists the devices visible to Xcode. The guided run asks for the Apple
development Team ID, a unique reverse-domain bundle identifier, the selected
iPhone identifier, and optionally a LAN relay URL. It then:

1. runs the Swift protocol tests, firmware-image integrity tests, and installer
   tests;
2. builds a Release iPhone app with automatic signing;
3. installs the new signed app on the selected iPhone without launching it; and
4. saves the signing choices and relay URL to
   `~/.config/hatch-alarm-clock-debloat/config.json` with owner-only
   permissions.

Use the same bundle identifier on later runs to replace and renew the existing
copy while preserving the remembered Restore. A free Apple development
signature can expire; running `./install` again builds and installs a newly
signed copy.

The installer performs no BLE connection, clock command, cloud request, router
change, firmware build, or firmware write. The clock continues its current
routine while the phone app is renewed.

Opening Rose Control establishes the BLE control connection but sends no light,
sound, clock, alarm, network, or cloud command until the owner chooses a control.
