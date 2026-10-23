class_name AisoraBackgroundBudget
extends RefCounted
## Sustained-load reductions affect decoration before character resolution.
## Hysteresis is one-way until settings change; no quality oscillation.
var factor: float=1.
var _elapsed: float=0.
var _frames: int=0
var _windows: int=0
var _cooldown: float=4.
func reset() -> void:factor=1.;_elapsed=0.;_frames=0;_windows=0;_cooldown=4.
func observe(delta: float,target: int,eligible: bool) -> bool:
	if not eligible or delta<=0. or not is_finite(delta):_elapsed=0.;_frames=0;_windows=0;return false
	_cooldown=maxf(0.,_cooldown-delta)
	if _cooldown>0. or factor<=0.:return false
	_elapsed+=minf(delta,1.);_frames+=1
	if _elapsed<2.:return false
	_windows=_windows+1 if _elapsed/_frames>1./clampi(target,15,60)+.006 else 0
	_elapsed=0.;_frames=0
	if _windows<2:return false
	factor=.6 if factor>.61 else (.3 if factor>.31 else 0.)
	_windows=0;_cooldown=6.;return true
