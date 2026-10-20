# Engineering status

## Complete in source

- Direct local BLE controller with no Hatch login UI or cloud fallback.
- Light, volume, stop, included-sound, direct-radio, and locally constructed alarm paths.
- JSON packet framing and response reassembly.
- Native display-text and display-animation command encoding.
- Tested Colossus light scene with cancellation and warm-light restoration.
- Exact-source firmware patch builder with source-byte guards, ESP32 checksum repair, and appended-hash repair.
- Optional OpenWrt audio relay source.
- Guided iPhone installer and renewal path with deployment values kept outside
  the repository.

## Verified on hardware

- BLE discovery and acknowledged UART/JSON transport.
- Reversible light and sound controls.
- Included-sound playback using the catalog ID and exact media URL.
- Factory IoT-disconnect command acknowledgement.
- Display-command transport acknowledgement.

## Pending physical acceptance

- Visible display output for the newly identified native commands.
- Audible acceptance for configured internet-radio and owner-selected relay playback.
- Recovery access and complete flash dumps for both ESP32 modules.
- Any firmware write.
- Rebooted, offline alarm persistence after a future authorized firmware installation.

The repository records implemented and tested engineering work. Pending items remain pending until observed on the physical device.
