# Layered procedural animation

**Current: [Phase 6 controls and limits](../docs/PHASE6.md).** The Phase 2–5 notes below describe retained layers and historical capability boundaries. Phase 6 adds `ground_motion.gd` four-direction contact-based steps/turns, `limb_ik.gd` cached analytic two-bone solving, `full_body.gd` articulated seat/floor transitions and rig-specific skirt/tail corrections, `personality.gd` ten manual/weighted expressions and `behavior_scheduler.gd` opt-in time-aware major actions. Voice keeps precedence. Body/root/legs have one owner at a time; the face retains independent blink and real amplitude-driven `aa`. Rest retains breathing and small head/hand shifts; hair roots use a conservative recline correction. It does not implement full cloth simulation, arbitrary mocap or unrestricted travel.


`AisoraCharacter` retains the original VRM importer, skeleton and facial binding scan. `AisoraMotionLayers` in `scripts/motion_layers.gd` supplies independent dictionaries of additive rest-axis rotations:

| Layer | Ownership / behavior |
| --- | --- |
| Breathing | Small spine/chest motion and pelvis lift; varied breath period, slower during sleep |
| Posture | State poses, gentle sway and weight changes; optional calibrated stepping has a separate hip/knee/ankle IK owner |
| Gaze | Random look targets, smoothed head/neck turns; listening gaze stays close to the camera |
| Speech | Head nods/tilts and upper-body emphasis weighted by real output amplitude |
| Gesture | Occasional wave, stretch, inspection, posture adjustment, explanation or nod; eased entry/exit and randomized cooldowns |
| Face (character adapter) | Irregular blink/double-blink and state expressions, composed with independent amplitude-driven `aa` mouth morph |
| Hair (character adapter) | Small rotations of the 11 actual `J_Sec_Hair1_` roots attached to Head; six roots in low-power mode |

Pose composition begins from the imported rest pose every frame and clamps the final offsets. An explicit Z/X/Y rotation order relaxes/twists upper arms and mirrors elbow flexion while respecting the source skeleton axes. Wrists, torso and head have tighter limits than upper arms/elbows. No accumulated bone rotations, assumed motion clips or invented jaw bone are used. The source `aa` morph provides the visible mouth/jaw deformation; gestures and animation intensity cannot open the mouth in silence.

The scheduler avoids consecutive repeated idle gestures and randomizes initial delay, 8–15 second idle cooldowns, gaze, posture and breath targets. Listening uses small attentive nods; talking uses explanation/nod gestures. State changes fade an in-progress gesture out. Sleep suppresses gestures, eases into a bowed/tilted standing rest pose over 2.4 seconds, closes the eyes, relaxes the arms outside the wide skirt and slows breathing. Wake takes 1.8 seconds, with a small head/shoulder recovery lasting 2.6 seconds. Full-rate transitions finish before the settled-sleep rendering cap is applied.

Body/gaze/gesture/hair intensity is adjustable from 0 to 1.6; blink and lip sync remain functional. State posture remains recognizable at intensity zero. Full spring collision simulation is disabled; small procedural hair rotations are an economical visual approximation. There is no cloth collision solver. Conservative rotations and rendered pose inspection target this actual model, rather than promising that arbitrary replacement clothing will never clip.

To add a gesture, define its duration and bounded additive pose in `AisoraMotionLayers`, then add scheduler/preview eligibility and test it on the actual model. If adding an AnimationTree or imported clips later, define track ownership/blending before writing to the same bones. Automatic Listening means “Voice appears active without detected tab-output speech”; it does not prove microphone reception. Thinking stays a manual presentation state because the consumer page has no reliable thinking event.

Phase 3 keeps these poses/timings while caching rest-axis quaternions, joint limits and the four owned facial layers. Layer dictionaries are reused; unchanged native values skip uploads. Hair/eye bones update at up to 8 Hz (Low/low-power), 12 Hz (Balanced/High) or 4 Hz (inactive), while primary body/face updates follow every rendered frame. Efficient materials affect shading only; High restores the exact imported materials. See [Phase 3](../docs/PHASE3.md) and [performance measurements](../docs/PERFORMANCE.md).

Phase 4 adds [the standing action catalogue](../scripts/action_catalog.gd), weighted configurable scheduling and a conversation guard. Fifteen of the original 20 requested action types are implemented on the actual skeleton; standing sleep/wake is retained. Walking, seated/floor poses, full turns and rising from a seat/floor remain unavailable rather than being faked with root transforms. Hand targets were checked with forward kinematics; authored joint poses are blended procedurally, without per-frame IK or imported motion dependencies. See the complete numbered matrix, controls and limits in [PHASE4.md](../docs/PHASE4.md). `tools/capture_actions.gd` renders transition/peak/exit frames with original placeholder scenery only.

Phase 5 adds actual-rig forward-kinematics checks, bounded torso/head/skirt proxy protection, a forward approach into a loose arm fold, all-finger soft curls and queued gesture replacement. `ground_motion.gd` owns legs/root only during opt-in calibrated short steps; it uses planted targets and analytic two-bone IK, with breathing/head/face layers retained. Voice lands the current swing before holding. This is not a cloth solver or general walking/seat/floor system. See [Phase 5](../docs/PHASE5.md) for historical Phase 5 capabilities, multi-angle visual evidence and calibration limitations; the Phase 4 paragraph above is historical.
