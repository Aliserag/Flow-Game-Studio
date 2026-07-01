class_name TestFramework
extends RefCounted

# Minimal zero-dependency test framework. Designed to upgrade to GUT later
# without rewriting test files: GUT-style assert_eq / assert_true / assert_false
# methods translate directly to GUT's `assert_eq` etc.
#
# Usage:
#   TestFramework.reset()
#   TestFramework.suite("MySuite")
#   TestFramework.assert_eq(2, 1+1, "sum")
#   ...
#   print(TestFramework.summary())

static var _tests_run: int = 0
static var _failures: Array = []
static var _current_suite: String = ""
static var _suite_counts: Dictionary = {}  # suite -> {run: N, fail: N}

static func reset() -> void:
	_tests_run = 0
	_failures.clear()
	_current_suite = ""
	_suite_counts.clear()

static func suite(name: String) -> void:
	_current_suite = name
	if not _suite_counts.has(name):
		_suite_counts[name] = {"run": 0, "fail": 0}
	print("\n--- %s ---" % name)

static func _record_result(passed: bool, name: String, detail: String) -> void:
	_tests_run += 1
	if not _suite_counts.has(_current_suite):
		_suite_counts[_current_suite] = {"run": 0, "fail": 0}
	_suite_counts[_current_suite]["run"] += 1
	var label: String = "%s::%s" % [_current_suite, name] if _current_suite != "" else name
	if passed:
		print("  PASS  %s" % label)
	else:
		_failures.append("%s — %s" % [label, detail])
		_suite_counts[_current_suite]["fail"] += 1
		print("  FAIL  %s — %s" % [label, detail])

static func assert_eq(expected, actual, name: String) -> void:
	var passed: bool = (typeof(expected) == typeof(actual)) and (expected == actual)
	# Loosen on numeric equality across int/float.
	if not passed and (typeof(expected) in [TYPE_INT, TYPE_FLOAT]) and (typeof(actual) in [TYPE_INT, TYPE_FLOAT]):
		passed = float(expected) == float(actual)
	_record_result(passed, name, "expected %s (%s), got %s (%s)" % [
		str(expected), _type_name(typeof(expected)),
		str(actual), _type_name(typeof(actual))
	])

static func assert_true(value: bool, name: String) -> void:
	_record_result(value, name, "expected true, got %s" % str(value))

static func assert_false(value: bool, name: String) -> void:
	_record_result(not value, name, "expected false, got %s" % str(value))

static func assert_in_range(low: float, high: float, value: float, name: String) -> void:
	_record_result(value >= low and value <= high, name,
		"expected in [%f, %f], got %f" % [low, high, value])

static func assert_not_null(value, name: String) -> void:
	_record_result(value != null, name, "expected non-null, got null")

static func assert_array_size(arr: Array, expected_size: int, name: String) -> void:
	_record_result(arr.size() == expected_size, name,
		"expected size %d, got %d" % [expected_size, arr.size()])

static func assert_dict_has(d: Dictionary, key: String, name: String) -> void:
	_record_result(d.has(key), name, "expected key '%s' in dict (had %s)" % [key, str(d.keys())])

static func assert_almost(expected: float, actual: float, tolerance: float, name: String) -> void:
	_record_result(abs(expected - actual) <= tolerance, name,
		"expected ~%f (±%f), got %f" % [expected, tolerance, actual])

static func ok() -> bool:
	return _failures.is_empty()

static func summary() -> String:
	var passed: int = _tests_run - _failures.size()
	var s: String = "\n=== Test Summary ===\n"
	for suite_name in _suite_counts.keys():
		var c: Dictionary = _suite_counts[suite_name]
		s += "  %-32s %d/%d\n" % [suite_name, c.run - c.fail, c.run]
	s += "  --------\n"
	s += "  Total: %d run, %d passed, %d failed\n" % [_tests_run, passed, _failures.size()]
	if not _failures.is_empty():
		s += "\nFailures:\n"
		for f in _failures:
			s += "  - %s\n" % f
	return s

static func _type_name(t: int) -> String:
	match t:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT: return "Object"
		_: return "type%d" % t
