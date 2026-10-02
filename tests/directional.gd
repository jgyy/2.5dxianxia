extends SceneTree

const Directions = preload("res://scripts/directional_sprites.gd")
var checks = 0
var failed = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)

func _initialize() -> void:
	for index in range(12):
		var angle = index * TAU / 12
		check(Directions.view_index(angle) == index, "Thirty-degree sector center %d" % index)
		check(Directions.view_index(angle + TAU * 3) == index, "Positive full turns %d" % index)
		check(Directions.view_index(angle - TAU * 3) == index, "Negative full turns %d" % index)
		check(Directions.view_index(angle + deg_to_rad(14.9)) == index, "Below clockwise boundary %d" % index)
		check(Directions.view_index(angle + deg_to_rad(15.1)) == (index + 1) % 12, "Above clockwise boundary %d" % index)
	var origin = Vector3(17, 8, 60)
	check(Directions.relative_view(origin + Vector3(0, 2, 3), origin, PI) == 0, "Observer in front of a south-facing resident")
	check(Directions.relative_view(origin + Vector3(3, 2, 0), origin, PI) == 3, "Observer at the left profile")
	check(Directions.relative_view(origin + Vector3(0, 2, -3), origin, PI) == 6, "Observer behind the resident")
	check(Directions.relative_view(origin + Vector3(-3, 2, 0), origin, PI) == 9, "Observer at the right profile")
	check(Directions.relative_view(origin, origin, PI) == 0, "Coincident horizontal position remains deterministic")
	print("DIRECTIONAL_TESTS checks=%d passed=%d failed=%d" % [checks, checks - failed, failed])
	quit(1 if failed else 0)
