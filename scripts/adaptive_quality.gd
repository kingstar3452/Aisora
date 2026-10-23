class_name AisoraAdaptiveQuality
extends RefCounted
## Opt-in reduction only. No FPS-cap changes and no automatic oscillating upgrades.
var enabled: bool=false
var effective_scale: float=1.
var _elapsed: float=0.
var _frames: int=0
var _bad_windows: int=0
var _cooldown: float=0.
func reset(selected: float) -> void:
 effective_scale=selected;_elapsed=0;_frames=0;_bad_windows=0;_cooldown=4.
func observe(delta: float,target_fps: int,eligible: bool) -> bool:
 if not enabled or not eligible or delta<=0 or not is_finite(delta):_elapsed=0;_frames=0;_bad_windows=0;return false
 _cooldown=maxf(0.,_cooldown-delta)
 if _cooldown>0:return false
 _elapsed+=minf(delta,1.);_frames+=1
 if _elapsed<2.:return false
 var mean: float=_elapsed/maxi(1,_frames)
 _bad_windows=_bad_windows+1 if mean>1./clampi(target_fps,15,60)+.007 else 0
 _elapsed=0;_frames=0
 if _bad_windows<3 or effective_scale<=.5:return false
 effective_scale=.75 if effective_scale>.76 else (.6 if effective_scale>.61 else .5)
 _bad_windows=0;_cooldown=8.;return true
