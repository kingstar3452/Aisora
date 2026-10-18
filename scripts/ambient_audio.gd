class_name AisoraAmbientAudio
extends AudioStreamPlayer
## Optional original synthetic loops. Silent by default and ducked during any Voice guard.
var level: float=0.
var _gain: float=0.
var _key: String=""
var _pending: String=""
func advance(period: String,weather: String,voice: bool,delta: float) -> void:
 var desired: String="nighttime" if period=="nighttime" else ("morning" if period=="morning" else "wind")
 if weather in ["light_rain","heavy_rain","windy"]:desired="wind"
 _pending=desired
 var target: float=0. if voice or level<=0. or _pending!=_key else clampf(level,0,.25)
 _gain=move_toward(_gain,target,maxf(0.,delta)*(.5 if target<_gain else .15))
 volume_db=linear_to_db(maxf(.00001,_gain))
 if _gain<=.0001:
  if playing:stop()
  if level>0. and not voice and _pending!=_key:
   var value: AudioStreamWAV=load("res://assets/ambience/%s.wav"%_pending)
   value.loop_mode=AudioStreamWAV.LOOP_FORWARD;value.loop_begin=0;value.loop_end=roundi(value.get_length()*value.mix_rate)
   stream=value;_key=_pending;play()
 if _gain>0. and not playing and stream!=null:play()
