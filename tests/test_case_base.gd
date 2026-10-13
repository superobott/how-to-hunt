extends "res://tests/case_base.gd"
## Tests for the assertion helpers themselves: a helper that cannot fail is worse than none.

const CaseBase := preload("res://tests/case_base.gd")


func test_assert_near_fails_on_nan_and_infinity() -> void:
	for bad in [NAN, INF, -INF]:
		var probe := CaseBase.new()
		probe.assert_near(bad, 0.0, "bad actual")
		assert_eq(probe.errors.size(), 1, "assert_near rejects %s as actual" % str(bad))
		probe = CaseBase.new()
		probe.assert_near(0.0, bad, "bad expected")
		assert_eq(probe.errors.size(), 1, "assert_near rejects %s as expected" % str(bad))


func test_assert_vec3_near_fails_on_non_finite_components() -> void:
	for bad in [Vector3(NAN, 0, 0), Vector3(0, INF, 0), Vector3(0, 0, -INF)]:
		var probe := CaseBase.new()
		probe.assert_vec3_near(bad, Vector3.ZERO, "bad actual")
		assert_eq(probe.errors.size(), 1, "assert_vec3_near rejects %s as actual" % str(bad))
		probe = CaseBase.new()
		probe.assert_vec3_near(Vector3.ZERO, bad, "bad expected")
		assert_eq(probe.errors.size(), 1, "assert_vec3_near rejects %s as expected" % str(bad))


func test_assert_near_still_passes_for_close_finite_values() -> void:
	var probe := CaseBase.new()
	probe.assert_near(1.00001, 1.0)
	probe.assert_vec3_near(Vector3(1, 2, 3), Vector3(1, 2, 3.00001))
	assert_eq(probe.errors.size(), 0, "close values pass")
