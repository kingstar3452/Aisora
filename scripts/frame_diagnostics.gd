class_name AisoraFrameDiagnostics
extends RefCounted
## Fixed-size ring buffer. Sorting/formatting only when the visible overlay refreshes.
var samples: PackedFloat32Array = PackedFloat32Array()
var count: int = 0
var cursor: int = 0
func _init() -> void:
	samples.resize(120)
func record(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	samples[cursor] = delta*1000.0
	cursor = (cursor+1)%samples.size()
	count = mini(count+1,samples.size())
func snapshot() -> Dictionary:
	if count == 0: return {"fps": 0.0,"mean_ms": 0.0,"p95_ms": 0.0}
	var sorted: PackedFloat32Array = samples.slice(0,count)
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted: total += value
	var mean: float = total/count
	return {"fps":1000.0/mean,"mean_ms":mean,"p95_ms":sorted[mini(count-1,int(count*0.95))]}
