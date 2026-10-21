class_name AisoraActionCatalog
extends RefCounted
## Fifteen requested standing actions. Unsupported locomotion/rest poses are explicit.
const IDS: Array[String] = ["breathe","look_sides","look_up","look_down","fingers","hands","stretch","back_stretch","curious","fold_arms","hand_face","wave","weight_shift","brush_hair","playful"]
const REQUEST_NUMBERS: Array[int] = [1,2,3,4,5,6,7,8,9,10,11,12,15,19,20]
const LABELS: Array[String] = ["Breathing & posture","Look left / right","Look at the sky","Look down","Inspect fingers","Examine both hands","Stretch both arms","Stretch back","Curious head tilt","Fold arms","Hand near face","Wave","Shift weight","Brush hair aside","Playful hands"]
const WEIGHTS: Dictionary = {"breathe":1.7,"look_sides":1.2,"look_up":0.7,"look_down":0.6,"fingers":0.6,"hands":0.6,"stretch":0.7,"back_stretch":0.7,"curious":1.2,"fold_arms":0.4,"hand_face":0.6,"wave":0.4,"weight_shift":1.3,"brush_hair":0.6,"playful":0.3}
# These are deliberately not standing gestures: route through calibrated full-body controllers.
const UNAVAILABLE: Dictionary = {"turn_around":"Use calibrated step turns up to 90 degrees; no stationary 360-degree spin.","walk":"Use the calibrated four-direction walking controller.","sit":"Use the calibrated virtual seat controller.","lie_down":"Use the calibrated floor-rest controller.","floor_wake":"Use the full-body wake/stand transition."}
