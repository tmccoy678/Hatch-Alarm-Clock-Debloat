# Privacy

Rose Control is designed for direct control of an owner's Restore 2 without a
Hatch account.

## Data stored on the iPhone

The app stores the following values in its private application container:

- the Core Bluetooth identifier of the successfully paired Restore;
- the owner's local light and volume preferences;
- the bundled sound catalog cache;
- the locally constructed alarm document; and
- an optional custom radio URL entered by the owner.

The peripheral identifier is used only to reconnect to the same clock. Rose
Control contains no Hatch credential field, analytics SDK, advertising SDK, or
telemetry client.

Deleting the app removes its private iPhone data. Reinstalling over the existing
copy with the same bundle identifier preserves the container.

## Data stored on the Mac

The installer saves its renewal settings at:

```text
~/.config/hatch-alarm-clock-debloat/config.json
```

That owner-only file contains the Apple development Team ID, app bundle
identifier, selected iPhone identifier, optional LAN relay URL, and most recent
installation time. It is not committed to Git and is created with mode `0600`.

## Network behavior

Opening Rose Control performs local Bluetooth discovery and connection. It does
not send a clock command or contact a Hatch account service.

Network access occurs when the owner chooses a feature that requires it:

- an included sound or radio action gives the Restore the selected public media
  URL;
- owner-selected music can use the optional LAN relay and AirPlay route; and
- Xcode may contact Apple while signing or provisioning the locally built app.

Rose Control requests access to the iPhone media library only when the owner
opens the music-library feature. Selected media plays through the owner's iOS
and AirPlay path; the app does not upload the library or its metadata.

The destinations selected for radio, media, Apple signing, and an optional LAN
relay have their own privacy practices.

## Repository evidence

Do not publish peripheral identifiers, iPhone identifiers, Apple signing
details, LAN addresses, private media URLs, firmware dumps, maintenance keys,
or credentials in an issue or pull request. Follow [SECURITY.md](SECURITY.md)
for private reporting.
