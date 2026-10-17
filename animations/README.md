# Layered procedural animation

`AisoraCharacter` retains the original VRM importer, skeleton and facial binding scan. `AisoraMotionLayers` in `scripts/motion_layers.gd` supplies independent dictionaries of additive rest-axis rotations:

| Layer | Ownership / behavior |
| --- | --- |
| Breathing | Small spine/chest motion and pelvis lift; varied breath period, slower during sleep |
| Posture | State poses, gentle sway and weight changes; no stepping, with only millimeters of hip shift (no foot IK) |
| Gaze | Random look targets, smoothed head/neck turns; listening gaze stays close to the camera |
| Speech | Head nods/tilts and upper-body emphasis weighted by real output amplitude |
| Gesture | Occasional wave, stretch, inspection, posture adjustment, explanation or nod; eased entry/exit and randomized cooldowns |
| Face (character adapter) | Irregular blink/double-blink and state expressions, composed with independent amplitude-driven `aa` mouth morph |
| Hair (character adapter) | Small rotations of the 11 actual `J_Sec_Hair1_` roots attached to Head; six roots in low-power mode |

Pose composition begins from the imported rest pose every frame and clamps the final offsets. An explicit Z/X/Y rotation order relaxes/twists upper arms and mirrors elbow flexion while respecting the source skeleton axes. Wrists, torso and head have tighter limits than upper arms/elbows. No accumulated bone rotations, assumed motion clips or invented jaw bone are used. The source `aa` morph provides the visible mouth/jaw deformation; gestures and animation intensity cannot open the mouth in silence.

The scheduler avoids consecutive repeated idle gestures and randomizes initial delay, 8–15 second idle cooldowns, gaze, posture and breath targets. Listening uses small attentive nods; talking uses explanation/nod gestures. State changes fade an in-progress gesture out. Sleep suppresses gestures, eases into a bowed/tilted standing rest pose over 2.4 seconds, closes the eyes, relaxes the arms outside the wide skirt and slows breathing. Wake takes 1.8 seconds, with a small head/shoulder recovery lasting 2.6 seconds. Full-rate transitions finish before the settled-sleep rendering cap is applied.

Body/gaze/gesture/hair intensity is adjustable from 0 to 1.6; blink and lip sync remain functional. State posture remains recognizable at intensity zero. Full spring collision simulation is disabled; small procedural hair rotations are an economical visual approximation. There is no cloth collision solver. Conservative rotations and rendered pose inspection target this actual model, rather than promising that arbitrary replacement clothing will never clip.

To add a gesture, define its duration and bounded additive pose in `AisoraMotionLayers`, then add scheduler/preview eligibility and test it on the actual model. If adding an AnimationTree or imported clips later, define track ownership/blending before writing to the same bones. Automatic Listening means “Voice appears active without detected tab-output speech”; it does not prove microphone reception. Thinking stays a manual presentation state because the consumer page has no reliable thinking event.
