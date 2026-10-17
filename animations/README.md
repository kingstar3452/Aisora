# Animation layering

`AisoraCharacter` in `scripts/character_controller.gd` owns the five-state presentation machine. Imported VRM expression animations are inspected as **bindings**, not assumed motion clips. Supported facial tracks are mapped to actual MeshInstance3D blend-shape indices; simultaneous weights accumulate and clamp. The model's AnimationPlayer is not played over the procedural poses.

Every frame derives controlled bone rotations/positions from the original imported resting pose, preventing accumulated drift. Upper arms are relaxed relative to the skeleton's world rest axes, so the authored T-pose does not remain on screen. Tiny spine/hips motion supplies breathing/posture shifts; neck/head and eye movement use low-frequency motion and irregular gaze targets. Sleep/listen/think/talk weights interpolate exponentially. Irregular eyelid animation and audio mouth weights are independent.

To add a compatible animation later, introduce an AnimationTree layer or explicit pose source and define ownership of the affected bones. Do not run a clip and procedural code on the same tracks without a blending policy. If replacing the VRM, revalidate bone names, expression maps, materials and camera framing; this implementation targets the uploaded humanoid with importer-normalized names.

Automatic Listening means “Voice appears active, with no detected output speech.” It does not prove that ChatGPT is receiving microphone audio. Thinking is intentionally a manual presentation state because the consumer DOM offers no reliable thinking event. No conversational content/personality logic lives here.
