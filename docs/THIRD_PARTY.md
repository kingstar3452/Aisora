# Third-party provenance and licenses

## Bundled importer

[V-Sekai/godot-vrm](https://github.com/V-Sekai/godot-vrm), pinned commit `e15199f980064028bfa4fbee5e70dddb82dd55c3` (2026-07-08). The upstream documents Godot 4.0+ and VRM 0.0/1.0 support; imported VRM 0 expressions use VRM 1 names (`A` → `aa`, etc.). This integration is actually tested with Godot 4.6.3. Its recent upstream history and Godot 4.7 update indicate active maintenance at inspection; that is not a future compatibility guarantee.

Only `addons/vrm` and `addons/Godot-MToon-Shader` are bundled, with their original MIT licenses intact. No upstream sample models are included. Original paths are required by generated resources. The full upstream license is also in `docs/licenses/godot-vrm-LICENSE`.

Two local importer fixes are applied and should be rechecked on upgrades:

- `import_vrm.gd` initializes the optional `vrm/already_processed` additional-data key to null before import. Godot 4.6 otherwise emits an engine dictionary error on a first access to the absent key.
- `vrm_extension.gd` uses `get_node_or_null("secondary")` before creating a missing VRM secondary node, avoiding a spurious missing-node error. Hair spring simulation is separately disabled by application policy at runtime, including the importer's internal SkeletonModifier3D.

Two upstream trailing-whitespace lines in `mtoon_common.gdshaderinc` and `vrm_utils.gd` are cleaned up for patch checks. Subtree `.gitrepo` metadata is omitted; provenance is pinned above.

## Existing character

`assets/character/aisora.vrm` is the unmodified byte-for-byte uploaded `Aisora prototype.vrm` from repository commit `08a3f63210c4f03641ef4d021b2dc56dd17b8834`. Only its path was changed. Its embedded VRM 0.0 metadata states `OnlyAuthor`, `Redistribution_Prohibited`, and disallows commercial use. The importer and project code do not grant additional character rights. Use the existing asset under its owner's permissions; don't treat the importer's MIT license as covering it.

## Investigated but not bundled

All three requested repositories were verified by successful HTTPS Git reads and source inspection. No code was copied from them.

| Repository / inspected commit | What the source actually provides | License evidence | Decision |
| --- | --- | --- | --- |
| [jwoglom/chatgpt-voice-bridge](https://github.com/jwoglom/chatgpt-voice-bridge) · `e8d851eaa278dc31ab6ecb430538cf82ae603ad2` | Docker, Chromium/Playwright, PulseAudio and SIP call bridging. `automation/bot.py` attempts native Voice button clicks. | README says MIT; no standalone LICENSE in inspected root. | Too heavy for this Mac workflow; does not demonstrate existing-Mac-browser compatibility. |
| [yukimaru77/chatgpt-voice-enhancements](https://github.com/yukimaru77/chatgpt-voice-enhancements) · `56c883cba028e1ea81289d8ed36846c309879201` | Runtime debugger injection into specific ChatGPT/Codex desktop app builds, project routing and Voice enhancements. | No explicit license file or grant found in inspected checkout. | Not a browser-tab controller. Not reused; no assumed permission to copy. |
| [chitoku/ChatGPTVoiceLauncher](https://github.com/chitoku/ChatGPTVoiceLauncher) · `4df9f007c16262254446d294ce35ff5b5c45f5da` | Windows .NET/WinForms tray app; Vosk/Porcupine wake words and ChatGPT activation attempts. | MIT in LICENSE.txt, with unfilled year/name placeholders. Dependencies/assets have separate terms. | Windows-only, unnecessary microphone/wake-word processing for this request. |

Inspection confirms repository existence and implementation scope, not operational success on an authenticated consumer account. GitHub REST metadata was inaccessible in this cloud network; the Git proxy was sufficient to inspect source and license files.
