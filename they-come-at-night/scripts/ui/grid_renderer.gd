extends Control

# Custom-drawn grid renderer. Reads from GameState.grid each repaint.
# Click handler emits a signal with the tile coordinate.

signal tile_clicked(coord: Vector2i)
signal tile_hovered(coord: Vector2i)

const CELL_SIZE := 38

var hover_cell: Vector2i = Vector2i(-1, -1)
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_PASS

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if GameState.grid == null:
		return
	var g: Grid = GameState.grid
	for x in g.size.x:
		for y in g.size.y:
			_draw_cell(g, Vector2i(x, y))
	# Highlight player tile.
	if not GameState.party.is_empty():
		var pp: Vector2i = GameState.party[0].pos
		var rect := Rect2(pp.x * CELL_SIZE, pp.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(rect, Color(1, 1, 1, 1), false, 2.0)
	# Hover ring.
	if hover_cell.x >= 0:
		var rect := Rect2(hover_cell.x * CELL_SIZE, hover_cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(rect, Color(1, 1, 0, 0.7), false, 1.0)

func _draw_cell(g: Grid, c: Vector2i) -> void:
	var t: Tile = g.get_tile(c)
	if t == null: return
	var rect := Rect2(c.x * CELL_SIZE, c.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
	var col: Color = t.color()
	# Fog of war: darken if not currently visible; black if never explored.
	if not t.explored:
		draw_rect(rect, Color(0.05, 0.05, 0.07, 1.0), true)
		return
	if not t.visible:
		col = col.darkened(0.55)
	draw_rect(rect, col, true)
	# Cell border.
	draw_rect(rect, Color(0, 0, 0, 0.4), false, 1.0)

	# Glyph.
	var glyph: String = t.glyph()
	# Entity glyph overrides terrain (only if visible).
	if t.visible and not t.entities.is_empty():
		glyph = t.first_entity_glyph()
	# Base marker overlay.
	if t.has_base:
		# Yellow circle in corner.
		draw_circle(rect.position + Vector2(6, 6), 4, Color(1, 0.85, 0.2, 0.9))
	# Searched dot.
	if t.searched and t.entities.is_empty():
		draw_circle(rect.position + Vector2(CELL_SIZE - 6, CELL_SIZE - 6), 2, Color(0, 0, 0, 0.4))
	# Glyph text centred.
	var glyph_color := Color(0.95, 0.95, 0.85)
	if t.visible and not t.entities.is_empty():
		# Use entity color if entity present.
		for e in t.entities:
			if e.color != Color.WHITE:
				glyph_color = e.color
				break
	var text_pos: Vector2 = rect.position + Vector2(CELL_SIZE * 0.5 - 5, CELL_SIZE * 0.5 + 6)
	draw_string(_font, text_pos, glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, glyph_color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := _coord_at(event.position)
		if c != hover_cell:
			hover_cell = c
			emit_signal("tile_hovered", c)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := _coord_at(event.position)
		if c.x >= 0:
			emit_signal("tile_clicked", c)

func _coord_at(p: Vector2) -> Vector2i:
	var c := Vector2i(int(p.x / CELL_SIZE), int(p.y / CELL_SIZE))
	if GameState.grid == null or not GameState.grid.in_bounds(c):
		return Vector2i(-1, -1)
	return c
