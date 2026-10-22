# Aisora Phase 6 — Intel macOS ad-hoc repair candidate (r2)

This candidate fixes bundle-signing defects in the earlier ZIP. It is ad-hoc signed, NOT Apple Developer ID signed or notarized. Linux checks passed; native macOS Ventura launch, Gatekeeper acceptance, quarantine propagation and authenticated ChatGPT Voice remain untested. Apple signing credentials are unavailable. Normal Gatekeeper launch is not guaranteed.

1. Download Aisora-phase6-macos.zip from https://github.com/kingstar3452/Aisora/releases/tag/phase6-macos-2026-10-22-r2 . Keep your previous app for rollback.
2. Double-click the ZIP in Finder to extract Aisora.app using Archive Utility. Move the app to your preferred application folder and open it. Godot is not required.
3. If macOS offers its normal Open/Open Anyway approval, review it for this app. If it still says “damaged” and provides no approval, stop and report the exact message. Do not disable Gatekeeper, remove quarantine, or use Terminal permission/security workarounds.

The app uses the existing Aisora user-data folder, so keep your settings and locally imported images. Phase 6 character, movement, personality gestures, weather, time-of-day system and Voice bridge compatibility are unchanged. The Python Voice bridge and Chromium extension remain separate: follow the existing setup and use the app's pairing-file picker. Do not delete local user data when replacing the app.

ZIP SHA-256:
bb59120067fcaddb4c320fbf29d0f2a7da338e587b4ee223d61c8e670315ba3f
Size: 56,715,169 bytes.

Linux validation: ZIP CRC/paths, executable permissions, thin Intel x86_64 Mach-O, minimum OS load command 10.13, all 23,123 executable page hashes, Info.plist and resource seals, four sealed resources including the project pack. 516 core checks and 24 real Godot Compatibility rendering checks against the pack extracted from this exact ZIP passed. These checks do not establish Apple trust or native Mac behavior. The cross-platform signer's verify command reported an empty-CMS parsing error for this ad-hoc signature and is not counted as a passing native verification.

Diagnosis, build steps and native acceptance checklist:
https://github.com/kingstar3452/Aisora/blob/bf2aee817f26da62a03187f9363580f57f71aeec/docs/MACOS_LAUNCH_REPAIR.md

Previous release preserved:
https://github.com/kingstar3452/Aisora/releases/tag/phase6-macos-2026-10-22
