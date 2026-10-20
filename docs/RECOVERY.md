# Recovery

## Expired or unavailable iPhone app

Run `./install` again with the same development team and bundle identifier. The
installer rebuilds Rose Control with a current signature and installs it over
the unavailable copy. It does not launch the app or contact the clock.

If iOS removed the old app, the same installer produces a clean installation.
The clock's light, sound, time, physical controls, and stored alarms operate on
the clock and remain outside this app-install procedure.

## Automatic Bluetooth recovery

Rose Control saves the successfully connected Restore's Core Bluetooth
identifier inside the app's private iPhone storage. On every launch and after a
Bluetooth interruption, it first reconnects to that saved device, then checks
for an existing iOS connection, then falls back to nearby discovery. No Hatch
credentials are collected or stored.

The clock's Bluetooth button can be required again after a clock reset, a new
phone, or removal of the iOS Bluetooth bond. Routine app renewal with the same
bundle identifier preserves the app container and remembered device.

Follow [Pairing and everyday use](PAIRING.md) before opening a new pairing
window. Ordinary app relaunches and Bluetooth interruptions recover
automatically.

## Remove the local controller

Delete Rose Control from the iPhone like any other app. The private reinstall
settings remain at
`~/.config/hatch-alarm-clock-debloat/config.json` on the Mac so a later run can
use the same signing identity. Delete that file if the saved device, team,
bundle, and relay choices should also be forgotten.

## Firmware boundary

The repository's prepared Restore 2 firmware patch has not been flashed. A
firmware recovery procedure requires complete verified flash dumps, identified
programming connections, and eFuse security inspection for both ESP32 modules.
The iPhone installer does not cross that boundary.
