extends RefCounted
## Base class for test files. Assertions record errors instead of aborting,
## and the runner reports them after each test method.

var errors: Array[String] = []


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		errors.append(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		errors.append(message)


func assert_near(actual: float, expected: float, message: String = "", tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		errors.append("%s expected about %s but got %s" % [message, str(expected), str(actual)])


func assert_vec3_near(actual: Vector3, expected: Vector3, message: String = "", tolerance: float = 0.0001) -> void:
	if actual.distance_to(expected) > tolerance:
		errors.append("%s expected about %s but got %s" % [message, str(expected), str(actual)])


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		errors.append("%s expected %s but got %s" % [message, str(expected), str(actual)])
