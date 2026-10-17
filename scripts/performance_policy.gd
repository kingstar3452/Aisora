class_name AisoraPerformancePolicy
extends RefCounted
## Rendering policy only. It never stops/pauses the bridge or sends a Voice command.
var fps_limit: int = 30
var low_power: bool = false
var focused: bool = true
var minimized: bool = false

func frame_cap(resting: bool) -> int:
	var cap: int = clampi(fps_limit, 15, 60)
	if low_power:
		cap = mini(cap, 15)
	if resting:
		cap = mini(cap, 10)
	if not focused:
		cap = mini(cap, 10)
	if minimized:
		cap = mini(cap, 5)
	return cap
