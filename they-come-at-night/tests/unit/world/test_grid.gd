class_name GridTest
extends RefCounted

static func run_all() -> void:
	TestFramework.suite("Grid")
	_test_in_bounds()
	_test_chebyshev()
	_test_manhattan()
	_test_neighbors4_corner()
	_test_neighbors8_edge()
	_test_step_toward()
	_test_add_remove_entity()
	_test_move_entity()
	_test_random_edge_position()

static func _test_in_bounds() -> void:
	var g: Grid = Grid.new(Vector2i(10, 10))
	TestFramework.assert_true(g.in_bounds(Vector2i(0, 0)), "in_bounds origin")
	TestFramework.assert_true(g.in_bounds(Vector2i(9, 9)), "in_bounds far corner")
	TestFramework.assert_false(g.in_bounds(Vector2i(-1, 0)), "in_bounds negative x")
	TestFramework.assert_false(g.in_bounds(Vector2i(0, -1)), "in_bounds negative y")
	TestFramework.assert_false(g.in_bounds(Vector2i(10, 0)), "in_bounds x at size")
	TestFramework.assert_false(g.in_bounds(Vector2i(0, 10)), "in_bounds y at size")

static func _test_chebyshev() -> void:
	var g: Grid = Grid.new(Vector2i(10, 10))
	TestFramework.assert_eq(0, g.chebyshev(Vector2i(3, 3), Vector2i(3, 3)), "chebyshev same point")
	TestFramework.assert_eq(3, g.chebyshev(Vector2i(0, 0), Vector2i(3, 3)), "chebyshev diagonal")
	TestFramework.assert_eq(5, g.chebyshev(Vector2i(0, 0), Vector2i(5, 2)), "chebyshev wider x")
	TestFramework.assert_eq(g.chebyshev(Vector2i(2, 7), Vector2i(8, 1)),
		g.chebyshev(Vector2i(8, 1), Vector2i(2, 7)), "chebyshev symmetry")

static func _test_manhattan() -> void:
	var g: Grid = Grid.new(Vector2i(10, 10))
	TestFramework.assert_eq(6, g.manhattan(Vector2i(0, 0), Vector2i(3, 3)), "manhattan diagonal")
	TestFramework.assert_eq(g.manhattan(Vector2i(2, 7), Vector2i(8, 1)),
		g.manhattan(Vector2i(8, 1), Vector2i(2, 7)), "manhattan symmetry")

static func _test_neighbors4_corner() -> void:
	var g: Grid = Grid.new(Vector2i(10, 10))
	var n: Array = g.neighbors4(Vector2i(0, 0))
	TestFramework.assert_array_size(n, 2, "neighbors4 corner has exactly 2")
	var n2: Array = g.neighbors4(Vector2i(5, 5))
	TestFramework.assert_array_size(n2, 4, "neighbors4 interior has 4")

static func _test_neighbors8_edge() -> void:
	var g: Grid = Grid.new(Vector2i(10, 10))
	var n: Array = g.neighbors8(Vector2i(0, 5))
	TestFramework.assert_array_size(n, 5, "neighbors8 edge has 5")
	var n2: Array = g.neighbors8(Vector2i(5, 5))
	TestFramework.assert_array_size(n2, 8, "neighbors8 interior has 8")

static func _test_step_toward() -> void:
	var g: Grid = Grid.new(Vector2i(10, 10))
	var step: Vector2i = g.step_toward(Vector2i(0, 0), Vector2i(5, 0))
	TestFramework.assert_eq(Vector2i(1, 0), step, "step_toward east")
	step = g.step_toward(Vector2i(5, 5), Vector2i(0, 0))
	# Greedy: bigger axis first; both equal, x wins.
	TestFramework.assert_eq(Vector2i(4, 5), step, "step_toward diagonal toward origin")

static func _test_add_remove_entity() -> void:
	var g: Grid = TestHelpers.make_grid()
	var lead: Survivor = TestHelpers.make_lead_at(Vector2i(2, 2))
	g.add_entity(lead)
	TestFramework.assert_eq(1, g.entities.size(), "entity added to grid.entities")
	TestFramework.assert_eq(1, g.get_tile(Vector2i(2, 2)).entities.size(), "entity added to tile")
	g.remove_entity(lead)
	TestFramework.assert_eq(0, g.entities.size(), "entity removed from grid")
	TestFramework.assert_eq(0, g.get_tile(Vector2i(2, 2)).entities.size(), "entity removed from tile")

static func _test_move_entity() -> void:
	var g: Grid = TestHelpers.make_grid()
	var lead: Survivor = TestHelpers.make_lead_at(Vector2i(2, 2))
	g.add_entity(lead)
	g.move_entity(lead, Vector2i(3, 3))
	TestFramework.assert_eq(0, g.get_tile(Vector2i(2, 2)).entities.size(), "entity left old tile")
	TestFramework.assert_eq(1, g.get_tile(Vector2i(3, 3)).entities.size(), "entity arrived at new tile")
	TestFramework.assert_eq(Vector2i(3, 3), lead.pos, "entity.pos updated")

static func _test_random_edge_position() -> void:
	TestHelpers.seed_rng()
	var g: Grid = Grid.new(Vector2i(10, 10))
	for _i in 20:
		var p: Vector2i = g.random_edge_position()
		var on_edge: bool = p.x == 0 or p.x == 9 or p.y == 0 or p.y == 9
		TestFramework.assert_true(on_edge, "random_edge_position returns edge tile")
		TestFramework.assert_true(g.in_bounds(p), "random_edge_position in bounds")
