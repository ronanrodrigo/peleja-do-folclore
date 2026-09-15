extends GutTest
## Hitbox e hurtbox: sobreposicao pura, sem fisica da engine.

func test_empty_box_never_intersects() -> void:
	var box := BoundingBox.empty()
	assert_true(box.is_empty(), "caixa vazia nao tem area")
	assert_false(box.intersects(BoundingBox.new(Vector2i.ZERO, Vector2i(10, 10))))


func test_overlapping_boxes_intersect() -> void:
	var body := BoundingBox.new(Vector2i(0, 0), Vector2i(10, 10))
	assert_true(body.intersects(BoundingBox.new(Vector2i(5, 5), Vector2i(10, 10))))


func test_boxes_that_only_touch_the_border_do_not_intersect() -> void:
	var body := BoundingBox.new(Vector2i(0, 0), Vector2i(10, 10))
	var next_to_it := BoundingBox.new(Vector2i(10, 0), Vector2i(10, 10))
	assert_false(body.intersects(next_to_it), "encostar na borda nao e contato")
	assert_false(body.intersects(BoundingBox.new(Vector2i(12, 3), Vector2i(10, 10))))


func test_intersects_accepts_null() -> void:
	var body := BoundingBox.new(Vector2i.ZERO, Vector2i(4, 4))
	assert_false(body.intersects(null))


func test_negative_size_is_clamped_to_zero() -> void:
	var box := BoundingBox.new(Vector2i(3, 4), Vector2i(-5, -9))
	assert_eq(box.size, Vector2i.ZERO)
	assert_true(box.is_empty())


func test_from_size_and_translate() -> void:
	var box := BoundingBox.from_size(Vector2i(16, 20), Vector2i(2, 3))
	assert_eq(box.position, Vector2i(2, 3))
	assert_eq(box.size, Vector2i(16, 20))
	var moved := box.translated(Vector2i(-2, 5))
	assert_eq(moved.position, Vector2i(0, 8))
	assert_eq(moved.size, box.size)
	assert_eq(box.position, Vector2i(2, 3), "translated nao altera a caixa original")


func test_horizontal_distance_reports_gap_and_overlap() -> void:
	var left := BoundingBox.new(Vector2i(0, 0), Vector2i(10, 10))
	var right := BoundingBox.new(Vector2i(30, 0), Vector2i(10, 10))
	assert_eq(left.horizontal_distance_to(right), 20, "30 - 10 de vao")
	assert_eq(left.horizontal_distance_to(left), -10, "sobreposto devolve valor negativo")


func test_rect_matches_position_and_size() -> void:
	var box := BoundingBox.new(Vector2i(7, -18), Vector2i(18, 18))
	assert_eq(box.rect(), Rect2i(7, -18, 18, 18))
