# Compatibility

| Component | Current support |
| --- | --- |
| Alarm clock | Hatch Restore 2 |
| Phone app | Rose Control on iOS 17 or newer |
| Build host | macOS with Xcode and Swift |
| Local transport | Bluetooth Low Energy using the Restore communication service |
| App discovery | Restore service UUID, `Hatch Restore`, or the `RestoreV4` name prefix |
| Optional audio | Owner-supplied HTTP or HTTPS LAN relay URL |
| App distribution | Local Xcode build signed with the owner's Apple development team |

The local app contains no device-specific peripheral UUID, Apple development
team, private LAN address, or owner-specific Restore name. Those deployment
values stay in the owner's local installer configuration.

The supported compatibility claim covers the Restore 2 and iOS versions above.
Other Restore generations and Android have not been validated.

The firmware builder accepts only a source image whose SHA-256 is
`7339e11f8193db6180443b37a6a09f68c427404a931f28b54ff00380d90e23aa`.
That image constraint belongs to the research builder; the iPhone installer
does not read, build, or write firmware.
