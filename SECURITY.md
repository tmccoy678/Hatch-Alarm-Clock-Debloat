# Security policy

## Supported code

Security fixes are made on the default branch. Hardware and firmware support
is limited to the profiles listed in `docs/COMPATIBILITY.md`.

## Reporting a vulnerability

Do not publish firmware dumps, device identifiers, LAN addresses, credentials,
maintenance keys, or private audio URLs in an issue. Use GitHub private
vulnerability reporting when it is available. Otherwise, contact the
repository owner through their GitHub profile and request a private channel
without including sensitive details in the first message.

Useful reports identify the affected commit, Restore generation and firmware,
reproduction steps, impact, and the least-privileged evidence needed to confirm
the behavior. Remove personal and network identifiers from logs.

[PRIVACY.md](PRIVACY.md) lists the data stored by the app and installer and the
network paths activated by owner-selected features.

## Installer trust boundary

The supported installer builds and installs the local iPhone controller. Any
future firmware-writing mode must verify the exact source hash, complete flash
backups, eFuse state, programming access, and a tested restoration path before
writing a device. A bypass of these checks is security-relevant.
