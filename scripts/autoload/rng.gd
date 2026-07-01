extends Node

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func seed_run(s: int) -> void:
	_rng.seed = s

func randi_range_inclusive(low: int, high: int) -> int:
	if high < low:
		return low
	return _rng.randi_range(low, high)

func randf_unit() -> float:
	return _rng.randf()

func chance(p: float) -> bool:
	return _rng.randf() < p

func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]

func weighted_pick(items: Array, weights: Array):
	if items.is_empty():
		return null
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return items[0]
	var r := _rng.randi_range(1, total)
	var acc := 0
	for i in items.size():
		acc += int(weights[i])
		if r <= acc:
			return items[i]
	return items.back()

func weighted_pick_dict(weighted_dict: Dictionary):
	var keys := weighted_dict.keys()
	var weights: Array = []
	for k in keys:
		weights.append(int(weighted_dict[k]))
	return weighted_pick(keys, weights)
