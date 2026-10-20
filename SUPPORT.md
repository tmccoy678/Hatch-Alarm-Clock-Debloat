# Support

Start with `./install --check` and the troubleshooting guidance printed by the
installer. Search existing issues before opening a new one.

For a connection problem, bring Rose Control to the foreground, confirm iPhone
Bluetooth is on, stay near the Restore, and allow the automatic reconnect to
complete. Use the Restore's Bluetooth button for a new phone, a reset clock, a
removed iOS bond, or a newly identified app installation. See
[`docs/PAIRING.md`](docs/PAIRING.md).

For a useful support request, include the repository commit, Restore generation,
firmware version, macOS and Xcode versions, the installer stage that stopped,
and sanitized output. State whether the result came from a dry run, automated
test, BLE acknowledgement, or direct observation of the device.

Remove MAC addresses, peripheral UUIDs, Hatch account details, LAN addresses,
audio URLs, firmware contents, and backup paths before posting. Hardware outside
`docs/COMPATIBILITY.md` is a request for research rather than an installation
failure.
