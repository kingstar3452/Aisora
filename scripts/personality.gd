class_name AisoraPersonality
extends RefCounted
## Authored expressions, never inferred from transcripts, pitch, or Voice emotion.
const IDS: Array[String]=["unimpressed","eye_roll","smirk","dramatic_turn","mock_annoyance","laugh","curious_tilt","disbelief","point","hand_on_hip"]
const LABELS: Array[String]=["Unimpressed arm crossing","Playful eye roll","Mischievous smirk","Dramatic head turn","Mock annoyance","Amused laughter","Curious head tilt","Exaggerated disbelief","Playful finger pointing","Confident hand on hip"]
const WEIGHTS: Dictionary={"unimpressed":.5,"eye_roll":.4,"smirk":1.,"dramatic_turn":.25,"mock_annoyance":.4,"laugh":.3,"curious_tilt":1.2,"disbelief":.25,"point":.3,"hand_on_hip":.5}
const SHAPES: Array[String]=["Fcl_BRW_Angry","Fcl_BRW_Fun","Fcl_BRW_Joy","Fcl_BRW_Surprised","Fcl_EYE_Angry","Fcl_EYE_Joy","Fcl_EYE_Surprised","Fcl_MTH_Fun","Fcl_MTH_Up","Fcl_MTH_SkinFung_L"]
static func face(name: String,index: int) -> float:
 match name:
  "unimpressed":return .26 if index in [0,4] else (.08 if index==8 else 0.)
  "eye_roll":return .14 if index in [0,4] else 0.
  "smirk":return .26 if index==7 else (.15 if index==9 else (.12 if index==1 else 0.))
  "mock_annoyance":return .32 if index==0 else (.18 if index==4 else (.13 if index==7 else 0.))
  "laugh":return .38 if index in [2,5,7] else 0.
  "curious_tilt":return .16 if index in [1,3] else 0.
  "disbelief":return .38 if index==3 else (.22 if index==6 else 0.)
  "point","hand_on_hip":return .18 if index in [1,7] else 0.
 return 0.
