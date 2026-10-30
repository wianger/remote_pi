# Device-first navigation and ThreadDeck branding

The owner wants to choose a device first, then a workspace on that device,
then a session. The previous global directory/computer dropdown flattened
these two levels. Keep browsing selection separate from the active chat.

- Device includes all paired computers, including those with no cached rooms.
- Workspace lists only directories on the selected device. Session rows belong
  to that device/directory pair. Equal paths on two computers remain separate.
- Persist one atomic navigation preference with the device and each device's
  last explicit workspace. Migrate the earlier combined workspace selection.
- Switching either selector clears local search without changing the active
  transport or sending agent commands. Open a session explicitly to connect.
- Use ThreadDeck as the Android display name and a folded-thread geometric mark.
  Keep the installed package id, signing key, pairing data and update asset
  filename stable so the existing APK can be updated in place.
- Custom scope remains Android. No changes to the inherited iOS project.

Validation: widget tests cover two devices sharing a path, two conversations in
one workspace, empty devices, remembered workspaces and unchanged active chat.
Storage tests cover migration, serialized rapid changes and failed writes.
Render real Flutter previews, analyze/test, and build/sign an Android APK.
