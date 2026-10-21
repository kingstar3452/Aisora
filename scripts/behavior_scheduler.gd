class_name AisoraBehaviorScheduler
extends RefCounted
## Local scheduling only. Voice/scene/rig context contains no text or inferred emotion.
const DEFAULT_WEIGHTS: Dictionary={"personality":2.,"stretch":1.,"walk_forward":1.,"walk_backward":.5,"walk_left":.5,"walk_right":.5,"turn_left":.5,"turn_right":.5,"pace":.7,"sit":.5,"lie_down":.2,"sleep":.25}
var enabled: bool=false
var interval_min: float=45.
var interval_max: float=120.
var weights: Dictionary=DEFAULT_WEIGHTS.duplicate()
var wait: float=60.
var clock: float=0.
var last: String=""
var recent: Array[String]=[]
var cooldowns: Dictionary={}
var rng: RandomNumberGenerator=RandomNumberGenerator.new()
var selected_count: int=0
func _init(seed_value: int=0) -> void:
 if seed_value:rng.seed=seed_value
 else:rng.randomize()
func tick(delta: float,context: Dictionary) -> String:
 if not enabled or not is_finite(delta) or delta<=0.:return ""
 clock+=delta
 if context.get("voice",false):wait=maxf(wait,8.);return ""
 wait-=delta
 if wait>0. or not context.get("ready",false):return ""
 var candidates: Array[String]=[];var values: Array[float]=[];var total: float=0.
 for name: String in DEFAULT_WEIGHTS:
  if float(cooldowns.get(name,0.))>clock:continue
  if name not in ["personality","stretch"] and not context.get("ground",false):continue
  if name in ["sit","lie_down","sleep"] and not context.get("rest",false):continue
  if name=="sleep" and context.get("period","")!="nighttime":continue
  var value: float=clampf(float(weights.get(name,0.)),0.,5.)
  if context.get("period","")=="nighttime":value*=2. if name in ["sit","sleep"] else (.35 if name.begins_with("walk") or name=="pace" else .7)
  elif context.get("period","")=="morning" and name=="stretch":value*=2.
  if value<=0.:continue
  candidates.append(name);values.append(value)
 var has_fresh: bool=false
 for name: String in candidates:
  if name not in recent:has_fresh=true
 if has_fresh:
  for i in range(candidates.size()-1,-1,-1):
   if candidates[i] in recent:candidates.remove_at(i);values.remove_at(i)
 for value: float in values:total+=value
 if total<=0.:wait=1.;return ""
 var choice: float=rng.randf()*total
 for i in candidates.size():
  choice-=values[i]
  if choice>0.:continue
  last=candidates[i];selected_count+=1
  recent.append(last)
  if recent.size()>2:recent.pop_front()
  cooldowns[last]=clock+(300. if last in ["sit","lie_down","sleep"] else 90.)
  wait=rng.randf_range(clampf(interval_min,15.,300.),clampf(maxf(interval_min,interval_max),15.,600.))
  return last
 wait=1.;return ""
