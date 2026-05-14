extends Node
## Deterministic RNG singleton.
## All randomness in WARBAND routes through this — no direct randi()/randf() calls.
## A run's seed is set once at run start; every consumer uses the same engine,
## so the same seed always produces the same campaign.

var _engine: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_seed: int = 0


func _ready() -> void:
	# Default to a non-zero seed in case nothing seeds before first call
	set_seed(Time.get_unix_time_from_system())


func set_seed(seed_value: int) -> void:
	_current_seed = seed_value
	_engine.seed = seed_value
	Console.info("RNG seeded with %d" % seed_value, "rng")


func get_seed() -> int:
	return _current_seed


## Integer in [low, high] inclusive.
func roll_int(low: int, high: int) -> int:
	assert(low <= high, "roll_int: low must be <= high")
	return _engine.randi_range(low, high)


## Float in [0.0, 1.0).
func roll_float() -> float:
	return _engine.randf()


## Boolean with given probability of true.
func roll_chance(p: float) -> bool:
	return _engine.randf() < p


## Pick one element from a non-empty array.
func pick(arr: Array) -> Variant:
	assert(not arr.is_empty(), "pick: array is empty")
	return arr[_engine.randi_range(0, arr.size() - 1)]


## Weighted pick. weights array must parallel choices and sum > 0.
func pick_weighted(choices: Array, weights: Array) -> Variant:
	assert(choices.size() == weights.size(), "pick_weighted: size mismatch")
	assert(not choices.is_empty(), "pick_weighted: empty arrays")
	var total: float = 0.0
	for w in weights:
		total += float(w)
	assert(total > 0.0, "pick_weighted: total weight is 0")
	var r := _engine.randf() * total
	var acc := 0.0
	for i in choices.size():
		acc += float(weights[i])
		if r < acc:
			return choices[i]
	return choices.back()


## Shuffle an array in place using current seed.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _engine.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
