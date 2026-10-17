class_name AisoraAudioEnvelope
extends RefCounted
## RMS envelope, not phoneme recognition. Input must be browser OUTPUT audio.

var noise_gate: float = 0.012
var gain: float = 5.0
var mouth: float = 0.0
var speaking: bool = false
var silence_time: float = 0.0

func update(rms: float, fresh: bool, delta: float) -> float:
	var level: float = clampf(rms, 0.0, 1.0) if fresh and is_finite(rms) else 0.0
	var target: float = clampf((level - noise_gate) * gain, 0.0, 0.85)
	var rate: float = 24.0 if target > mouth else 12.0
	mouth = lerpf(mouth, target, 1.0 - exp(-rate * delta))
	if mouth < 0.001:
		mouth = 0.0
	if level > noise_gate * 1.5:
		speaking = true
		silence_time = 0.0
	else:
		silence_time += delta
		if silence_time >= 0.25 or not fresh:
			speaking = false
	return mouth
