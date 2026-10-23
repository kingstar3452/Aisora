class_name AisoraAutonomy
extends RefCounted
## Local policy and event pipeline. Never sends browser commands or starts speech.
signal dialogue_requested(event: Dictionary)
signal state_changed
const MODES: Array[String]=["quiet","balanced","talkative"]
const TRIGGERS: Array[String]=["avatar_hover","avatar_click","return","quiet_period","environment","greeting","scheduled","follow_up"]
const TEXT: Dictionary={
 "avatar_hover":["Yes? I'm spectacularly busy standing here.","Admiring the view? I meant the blossoms. Obviously."],
 "avatar_click":["You rang? This had better be interesting.","Oh, now I have your attention."],
 "return":["Welcome back. I was absolutely not waiting for you.","There you are. The blossoms kept me company."],
 "quiet_period":["A peaceful moment. Try not to look too impressed."],
 "environment":["A change of scenery. Even I approve."],
 "greeting":["Hello again. Try to keep up today."],
 "scheduled":["Your reminder: shall we have a chat?"],
 "follow_up":["You saved a topic for later. Shall we revisit it?"]}
var enabled: bool=true
var mode: String="talkative"
var mouse_tracking: bool=true
var head_tracking: bool=true
var hover_reactions: bool=true
var environment_comments: bool=true
var local_text: bool=true
var sensitivity: float=.7
var smoothing: float=5.
var cooldown_seconds: float=600.
var daily_limit: int=6
var quiet_hours: bool=true
var quiet_start: int=22
var quiet_end: int=8
var paused: bool=false
var dnd: bool=false
var silence: bool=false
var greeting: bool=false
var scheduled_hour: int=-1
var follow_up: String=""
var day: String=""
var count: int=0
var last_unix: float=0.
var _elapsed: float=0.
var _last_trigger: String=""
var _serial: int=0
var _environment: String=""
var _greeted: bool=false
var _scheduled_day: String=""
var _seen_active: bool=false
var _away: float=0.
var _quiet_elapsed: float=0.
var _followed: bool=false
var status: String="Local text only · proactive Voice unavailable"

func load_settings(cfg: ConfigFile) -> void:
 for key: String in ["enabled","mouse_tracking","head_tracking","hover_reactions","environment_comments","local_text","quiet_hours","paused","dnd","silence","greeting"]:
  set(key,bool(cfg.get_value("autonomy",key,get(key))))
 mode=str(cfg.get_value("autonomy","mode",mode));if mode not in MODES:mode="talkative"
 sensitivity=clampf(float(cfg.get_value("autonomy","sensitivity",sensitivity)),.1,1.)
 smoothing=clampf(float(cfg.get_value("autonomy","smoothing",smoothing)),1.,12.)
 cooldown_seconds=clampf(float(cfg.get_value("autonomy","cooldown_seconds",cooldown_seconds)),600.,7200.)
 daily_limit=clampi(int(cfg.get_value("autonomy","daily_limit",daily_limit)),0,24)
 quiet_start=clampi(int(cfg.get_value("autonomy","quiet_start",quiet_start)),0,23)
 quiet_end=clampi(int(cfg.get_value("autonomy","quiet_end",quiet_end)),0,23)
 scheduled_hour=clampi(int(cfg.get_value("autonomy","scheduled_hour",-1)),-1,23)
 follow_up=str(cfg.get_value("autonomy","follow_up"," ")).strip_edges().left(240)
 day=str(cfg.get_value("autonomy","day",""));count=maxi(0,int(cfg.get_value("autonomy","count",0)))
 last_unix=maxf(0.,float(cfg.get_value("autonomy","last_unix",0.)))
 _scheduled_day=str(cfg.get_value("autonomy","scheduled_day",""))

func save_settings(cfg: ConfigFile) -> void:
 for key: String in ["enabled","mode","mouse_tracking","head_tracking","hover_reactions","environment_comments","local_text","sensitivity","smoothing","cooldown_seconds","daily_limit","quiet_hours","quiet_start","quiet_end","paused","dnd","silence","greeting","scheduled_hour","follow_up","day","count","last_unix"]:
  cfg.set_value("autonomy",key,get(key))
 cfg.set_value("autonomy","scheduled_day",_scheduled_day)

func select_mode(value: String) -> void:
 if value not in MODES:return
 mode=value
 cooldown_seconds=1200. if mode=="balanced" else 600.
 daily_limit=3 if mode=="balanced" else (0 if mode=="quiet" else 6)
 state_changed.emit()

func in_quiet_hours(hour: int) -> bool:
 if not quiet_hours:return false
 if quiet_start==quiet_end:return true
 return (hour>=quiet_start or hour<quiet_end) if quiet_start>quiet_end else (hour>=quiet_start and hour<quiet_end)

func blocked(context: Dictionary, clock: Dictionary, now: float) -> String:
 if not enabled or mode=="quiet":return "Unsolicited dialogue off"
 if paused or dnd or silence:return "Paused / Do Not Disturb / silence"
 if context.get("conversation",false) or context.get("voice_uncertain",false):return "Conversation takes priority"
 if context.get("sleeping",false) or not context.get("focused",true):return "Resting or inactive"
 if in_quiet_hours(int(clock.hour)):return "Quiet hours"
 if count>=daily_limit:return "Daily limit reached"
 var minimum: float=maxf(cooldown_seconds,1200. if mode=="balanced" else 600.)
 if last_unix>0. and now-last_unix<minimum:return "Dialogue cooldown"
 return ""

func request_event(trigger: String,context: Dictionary,clock: Dictionary={},now: float=-1.) -> Dictionary:
 if trigger not in TRIGGERS:return {}
 if clock.is_empty():clock=Time.get_datetime_dict_from_system(false)
 if now<0.:now=Time.get_unix_time_from_system()
 var date: String="%04d-%02d-%02d"%[clock.year,clock.month,clock.day]
 if day!=date:day=date;count=0
 status=blocked(context,clock,now)
 if not status.is_empty():return {}
 if trigger=="environment" and not environment_comments:return {}
 if trigger=="avatar_hover" and not hover_reactions:return {}
 if trigger==_last_trigger:return {} # Repeated hovering is never a dialogue loop.
 count+=1;last_unix=now;_last_trigger=trigger;_serial+=1;_quiet_elapsed=0.
 var event: Dictionary={"type":"proactive_dialogue_request","trigger":trigger,"scene":context.get("scene","unknown"),"environment":context.get("environment","unknown"),"time_of_day":context.get("time_of_day","unknown"),"weather":context.get("weather","unknown"),"effects":context.get("effects",{}),"animation":context.get("animation","idle"),"state":context.get("state","idle"),"personality":"aisora","speech_allowed":false,"delivery":"local_text" if local_text else "event_only"}
 # Context excludes coordinates, imported image paths, window titles, transcripts and follow-up text.
 if local_text:
  var choices: Array=TEXT[trigger];event["text"]=choices[(_serial-1)%choices.size()]
 status="Local text only · proactive Voice unavailable"
 state_changed.emit();dialogue_requested.emit(event)
 return event

func advance(delta: float, context: Dictionary) -> void:
 _elapsed+=delta
 if not context.get("focused",true):_away+=delta;return
 if _away>=300. and _seen_active:request_event("return",context)
 _away=0.;_seen_active=true
 if context.get("conversation",false):_quiet_elapsed=0.
 else:_quiet_elapsed+=delta
 if _elapsed<1.:return
 _elapsed=0.
 var environment: String=str(context.get("environment","unknown"))+"/"+str(context.get("weather","unknown"))
 if not _environment.is_empty() and environment!=_environment:request_event("environment",context)
 _environment=environment
 if greeting and not _greeted:
  _greeted=true;request_event("greeting",context)
 var clock: Dictionary=Time.get_datetime_dict_from_system(false)
 var date: String="%04d-%02d-%02d"%[clock.year,clock.month,clock.day]
 if scheduled_hour==int(clock.hour) and _scheduled_day!=date:
  if not request_event("scheduled",context,clock).is_empty():_scheduled_day=date;state_changed.emit()
 if not follow_up.is_empty() and not _followed and _quiet_elapsed>=1800.:
  if not request_event("follow_up",context).is_empty():_followed=true
 if _quiet_elapsed>=1800.:
  request_event("quiet_period",context);_quiet_elapsed=0.
