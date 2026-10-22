# Phase 6 macOS bundle-signing repair

This is an **ad-hoc repair candidate**, authorized after the failed first release. It is **not Developer ID signed or notarized**. Signature consistency is tested in Linux; native Ventura launch and Gatekeeper acceptance remain untested. A normally trusted downloaded release still requires an Apple Developer ID Application certificate/private key and successful notarization. Those credentials are unavailable here.

## Findings from the actual failed download

The published application ZIP was downloaded again and its SHA-256 matched the reported `ea6511fd8017cc631b334e1c4a0022b353d53c7e9627f0aafbc0b0e77963d785`. This excludes a different/corrupted download as the explanation for this inspected copy.

- Its executable is thin Intel x86_64, with Unix mode `100755`. The minimum OS load command is macOS 10.13; the project pack and five illustrations are present. ZIP integrity and the basic app identity pass.
- Signing was disabled in the Godot preset. The executable retained the official template's embedded certificate signature, identifier **`godot_macos_release`**, rather than a signature for the assembled Aisora bundle.
- There is **no `Contents/_CodeSignature/CodeResources` resource seal**. The template CodeDirectory's Info.plist slot is zero/unbound. Executable page digests match, so this is not evidence of damaged machine-code bytes; it is an incorrectly finished distribution bundle.
- The old helper also added engine notices inside the app after export. If bundle signing were simply enabled, that ordering could add an unsealed file after signing. Every app content change must precede the final signing operation.

These are confirmed packaging defects consistent with the user's Gatekeeper error, not a native reproduction or proof that every Ventura launch problem has been eliminated. The previous checks missed bundle-signature validity. The previous release and original artifact remain available for rollback.

## What changed

Application scenes, original VRM, animation/behavior code, voice client, backgrounds/weather/clock and settings are unchanged. Only build tooling, regression tests and documentation change.

The helper now exports to an isolated staging directory, restores executable permissions, installs notices **before signing**, then re-signs the complete app. macOS uses its native `codesign --sign -` and strict native signature verification. Linux uses checksum-pinned **apple-codesign/rcodesign 0.29.0**, without a certificate, private key or timestamp. That tool is development-only and is not bundled with the app. The raw Godot preset alone is not a deliverable.

The trial Godot built-in signer emitted duplicate CodeDirectory indices. Rather than relaxing the new verifier to accept those, the Linux helper uses a separately pinned signer. Its `verify` subcommand reports an empty-CMS parsing error for ad-hoc signatures and is **not counted as a passing check**; it is not a substitute for Apple's native validation. Ad-hoc signing intentionally has no certificate CMS identity. Independent digest/seal checks below validate the produced candidate's consistency, not publisher trust.

An independent verifier checks:

- ZIP CRC, unique/canonical paths, normal bundle identity, executable permission, thin x86_64 architecture and minimum OS version.
- The Aisora signing identifier, every executable code-page hash, and embedded special-slot hashes, including Info.plist and CodeResources.
- Every sealed resource's SHA-256/SHA-1 where recorded, including the project pack, privacy manifest, icon and engine notices; unexpected unsealed app files are refused.
- Explicitly false Developer ID, notarization, native launch and Gatekeeper-assessment claims for Linux output.

A failed verification cannot replace an existing output ZIP. Packaging occurs after signing and does not modify the signed app. The signer preserves resource seals; Unix execute bits are recorded in the ZIP for Archive Utility.

## Build and check

```sh
python3 tools/prepare_export_templates.py
python3 tools/prepare_macos_signer.py   # On macOS this uses system codesign; no download.
python3 tools/export_macos.py --output exports/Aisora-phase6-macos.zip
python3 tools/macos_bundle.py exports/Aisora-phase6-macos.zip
./tools/check.sh
```

The Linux signer archive is pinned to SHA-256 `dbe85cedd8ee4217b64e9a0e4c2aef92ab8bcaaa41f20bde99781ff02e600002`, verified against the publisher's release checksum before installation. See [source/provenance](THIRD_PARTY.md). The signer is not an application runtime dependency.

Eleven new regression tests use a small structural Mach-O fixture and mutate its code pages, Info.plist, CodeResources, project pack, executable bits, architecture, paths and post-signing content. A valid ZIP CRC alone cannot make those altered bundles pass. These fixtures are not native macOS execution tests. The old published app is also rejected because its bundle resource seal is missing.

## Install the candidate using normal macOS controls

1. Keep your existing working app and local Aisora user-data folder. Download the **new repair candidate ZIP** from its release page; verify the new checksum if desired.
2. Extract with Finder/Archive Utility, move `Aisora.app` to your preferred application folder and open it. Godot is not required.
3. If macOS offers its normal Open/Open Anyway approval, review that approval for this app. Ad-hoc signing does not remove that trust requirement. **If macOS still says damaged and provides no approval, stop and report the message.** Do not remove quarantine, disable Gatekeeper, change executable permissions in Terminal, or bypass security checks.

No quarantine attribute is stripped by the builder. Browser downloads and Archive Utility can apply/propagate quarantine on the destination Mac. Its behavior cannot be reproduced by Linux ZIP inspection. No Terminal workaround is part of these installation instructions.

Existing local settings and imported image alternatives remain in the same Aisora user-data folder. Voice still uses the existing separate Python bridge/Chromium extension; use the app's pairing-file picker. No native authenticated Voice test is claimed.

## Requirements for a normally trusted release

A maintainer with a Mac must finish all content changes, sign the app with a valid **Developer ID Application** identity and hardened runtime, verify with Apple's strict `codesign`, submit to Apple's notarization service, require Accepted status, staple/validate the ticket, and assess with `spctl`. Final packaging should preserve the signed app/stapled metadata (for example with Apple's `ditto`). The browser-downloaded ZIP must then be extracted with quarantine intact and launched on Ventura. Certificate signing, notarization and native assessment are distinct checks; an ad-hoc signature or checksum does not replace them.

Apple credentials are configured through a secure keychain or secret settings, never posted in chat or committed. None were available for this candidate. No Gatekeeper-accepted, notarized or native-Mac-tested release is promised until that process is actually completed.

## Candidate validation record (22 October 2026)

The rebuilt `Aisora-phase6-macos.zip` is 56,715,169 bytes. Its SHA-256 is:

```text
bb59120067fcaddb4c320fbf29d0f2a7da338e587b4ee223d61c8e670315ba3f
```

The actual release candidate passes **516 core checks** (the existing 505 plus 11 packaging regressions) and **24 real Compatibility rendering checks against the PCK extracted from this exact ZIP** in Linux/Xvfb/Mesa. All five backgrounds decode and the original character/main scene instantiate from that pack. The independent verifier checks all **23,123 executable SHA-256 code pages**, the Info.plist and resource seals, and four resource files. Executable permissions are preserved and the minimum OS load command remains 10.13.

The helper's output verification JSON explicitly records `developer_id_verified=false`, `notarization_verified=false`, `gatekeeper_assessment_performed=false`, `native_macos_launch_performed=false` and `native_codesign_verification_performed=false`. The cross-platform signer's empty-CMS diagnostic described above is not counted as passed native verification. macOS launch/Gatekeeper, quarantine transfer behavior, authenticated Voice and target-iMac performance remain untested.

[New repair-candidate release](https://github.com/kingstar3452/Aisora/releases/tag/phase6-macos-2026-10-22-r2) · [Previous release preserved](https://github.com/kingstar3452/Aisora/releases/tag/phase6-macos-2026-10-22)
