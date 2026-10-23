class_name AisoraWorldCycle
extends RefCounted
## Local clock only. Lighting follows the image that actually exists, never a fake tint.
const SLOTS: Array[String] = ["morning", "daytime", "sunset", "nighttime"]
const IMAGE_SLOTS: Array[String]=["morning","daytime","sunset","nighttime","rain"]
const BUNDLED: Dictionary={"morning":"res://assets/world/morning.webp","daytime":"res://assets/world/daytime.webp","sunset":"res://assets/world/sunset.webp","nighttime":"res://assets/world/nighttime.webp","rain":"res://assets/world/rain.webp"}
const LABELS: Array[String] = ["Morning", "Daytime", "Sunset", "Nighttime"]
const PROFILES: Dictionary = {
 "rain": {"color":Color("ccd6e5"), "energy":.82, "ambient":.43},
 "morning": {"color":Color("ffe4bc"), "energy":1.02, "ambient":0.48},
 "daytime": {"color":Color("fff8ee"), "energy":1.10, "ambient":0.52},
 "sunset": {"color":Color("ffd4c1"), "energy":0.90, "ambient":0.43},
 "nighttime": {"color":Color("d5dff5"), "energy":0.78, "ambient":0.36}
}
var boundaries: PackedInt32Array = PackedInt32Array([360,720,1020,1200])
var override_slot: String = ""
var transition_seconds: float = 8.0

func set_boundaries(values: PackedInt32Array) -> bool:
 if values.size()!=4:return false
 for i in 4:
  if values[i]<0 or values[i]>=1440 or (i>0 and values[i]-values[i-1]<30):return false
 boundaries=values.duplicate();return true

func slot_at(minutes: int) -> String:
 if override_slot in SLOTS:return override_slot
 minutes=posmod(minutes,1440)
 var result: String="nighttime"
 for i in 4:
  if minutes>=boundaries[i]:result=SLOTS[i]
 return result

func local_slot() -> String:
 var local: Dictionary=Time.get_datetime_dict_from_system(false)
 return slot_at(int(local.hour)*60+int(local.minute))

static func profile(slot: String) -> Dictionary:
 return PROFILES.get(slot,PROFILES.sunset)
