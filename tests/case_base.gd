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


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		errors.append("%s expected %s but got %s" % [message, str(expected), str(actual)])
