# Contributing

Contributions should improve local control, accessibility, recovery safety, or
support for a precisely identified Hatch device and firmware combination.

1. Open an issue describing the device generation, firmware, intended behavior,
   and recovery evidence before adding a hardware profile.
2. Work on a short branch and keep each pull request focused.
3. Add tests for every changed protocol, command, safety gate, or installer
   decision.
4. Run the Swift, firmware, installer dry-run, and iOS build checks documented
   in the README.
5. Record physical light, sound, display, alarm, and reboot observations
   separately from transport acknowledgements and simulated tests.

Never commit vendor firmware, credentials, maintenance keys, private audio,
MAC addresses, peripheral identifiers, device dumps, or personal network
details. Use sanitized fixtures that preserve only the structure needed by a
test.
