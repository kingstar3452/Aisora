# Phase 6 Intel Mac test build

Built in Linux with Godot **4.6.3 official** export templates on **21 October 2026**. The final delivery includes `Aisora-phase6-macos.zip` (56,718,758 bytes), containing the unsigned **Intel x86_64** `Aisora.app`, resource pack and engine notices. The executable has its execute permission set; ZIP integrity, app bundle identity and x86_64 Mach-O header pass verification. An isolated Linux editor-based pack player loads all five images and the original skeleton/main scene from the Mac app's extracted pack. The Mac executable itself cannot run here.

SHA-256:

```text
03491c387b0bb260d72d3bec4eba8b5e9aa8a1bbbb51de25cc3e4c65de12ba25  Aisora-phase6-macos.zip
```

The ignored cloud artifact is at `.local/phase6-build/Aisora-phase6-macos.zip`; use the download link in the delivery or reproduce it from source. No app/template binary is committed to Git. The test app is **not signed or notarized**, and has no native Ventura launch, permission, Voice or iMac performance certification. Follow [Phase 6 setup and rollback](PHASE6.md) before replacing your working Phase 5 app. A separate Linux release export is used only for diagnostics; its initial severe startup stall and the clean-settings follow-up are recorded in [performance evidence](PERFORMANCE_PHASE6.md).

To reproduce (Godot 4.6.3 standard, Python 3.10+):

```sh
python3 tools/prepare_export_templates.py
python3 tools/export_macos.py --output exports/Aisora.zip
```

The first command is optional development setup, downloading the official ~1.26 GB template archive once and verifying its pinned archive/retained-file SHA-256 values. It prepares a separate Intel-only ZIP template from unchanged official Mach-O slices, preserving the original universal template. The second exports, validates structure, appends the committed exact engine notices and writes a checksum sidecar. Code signing/notarization require a separate native distribution workflow and are not performed.

After extracting, run the app with normal macOS approval for a trusted unsigned local app. Keep the Python bridge and extension installed from the source checkout; choose the current bridge pairing file in the exported viewer. Its images, preferences and rollback backup use the existing local Godot user-data folder.
