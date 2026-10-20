# Pairing and everyday use

## First installation

1. Add the owner's Apple ID in Xcode.
2. Connect, unlock, and trust the iPhone.
3. Enable Developer Mode on the iPhone when iOS requests it.
4. Run `./install --check`, followed by `./install`.
5. Open Rose Control from the iPhone Home Screen.
6. If the first connection does not reach the dashboard, hold the Restore's
   Bluetooth button to open its pairing window and leave Rose Control open.

When the dashboard appears, Rose Control saves that Restore's Core Bluetooth
identifier in its private iPhone storage.

## Everyday use

Open Rose Control. It tries the remembered Restore first, an existing iOS
connection second, and nearby discovery third. It reconnects automatically
after an ordinary Bluetooth interruption. No Hatch login or clock-button press
is part of the routine path.

Opening the app is passive. The app sends a device command only after the owner
selects a light, sound, alarm, display, or other control.

## Signature renewal

A free Apple development signature can expire. Run `./install` again with the
same bundle identifier. The installer replaces the signed app without launching
it and preserves the remembered device in the existing app container.

## When pairing may be required again

Open a new Bluetooth pairing window after any of these changes:

- the Restore was reset;
- the iOS Bluetooth bond was removed;
- the owner moved to a different iPhone; or
- the app was installed as a new identity with a different bundle identifier.

Routine app launches, Bluetooth interruptions, and signed-app renewal use the
remembered connection.
