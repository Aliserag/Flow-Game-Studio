extends Control

# Custom-drawn grid renderer. Reads from GameState.grid each repaint.
# Click handler emits a signal with the tile coordinate.

signal tile_clicked(coord: Vector2i)
signal tile_hovered(coord: Vector2i)

const CELL_SIZE := 38

# Render mode toggle. "sprite" uses the procedural SpriteGenerator; "glyph" falls
# back to the original ASCII renderer (debugging).
var render_mode: String = "sprite"

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
	# Fog of war: black if never explored.
	if not t.explored:
		draw_rect(rect, Color(0.05, 0.05, 0.07, 1.0), true)
		return
	if render_mode == "sprite":
		_draw_cell_sprite(t, rect)
	else:
		_draw_cell_glyph(t, rect)
	# Cell border (subtle).
	draw_rect(rect, Color(0, 0, 0, 0.4), false, 1.0)
	# Base marker overlay (gold star corner).
	if t.has_base:
		draw_circle(rect.position + Vector2(6, 6), 4, Color(1, 0.85, 0.2, 0.9))
	# Searched dot.
	if t.searched and t.entities.is_empty():
		draw_circle(rect.position + Vector2(CELL_SIZE - 6, CELL_SIZE - 6), 2, Color(0, 0, 0, 0.4))

func _draw_cell_sprite(t: Tile, rect: Rect2) -> void:
	var terrain_tex: ImageTexture = SpriteGenerator.get_terrain_texture(t.terrain_id)
	# Tint by fog: 100% when visible, 55% when only explored.
	var modulate := Color(1, 1, 1, 1) if t.visible else Color(0.45, 0.45, 0.55, 1)
	draw_texture_rect(terrain_tex, rect, false, modulate)
	# Top-most entity overlay.
	if t.visible and not t.entities.is_empty():
		var top = _top_entity(t)
		if top != null:
			var entity_tex: ImageTexture = SpriteGenerator.get_entity_texture(_entity_key(top))
			draw_texture_rect(entity_tex, rect, false, Color(1, 1, 1, 1))

func _draw_cell_glyph(t: Tile, rect: Rect2) -> void:
	var col: Color = t.color()
	if not t.visible:
		col = col.darkened(0.55)
	draw_rect(rect, col, true)
	var glyph: String = t.glyph()
	if t.visible and not t.entities.is_empty():
		glyph = t.first_entity_glyph()
	var glyph_color := Color(0.95, 0.95, 0.85)
	if t.visible and not t.entities.is_empty():
		for e in t.entities:
			if e.color != Color.WHITE:
				glyph_color = e.color
				break
	var text_pos: Vector2 = rect.position + Vector2(CELL_SIZE * 0.5 - 5, CELL_SIZE * 0.5 + 6)
	draw_string(_font, text_pos, glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, glyph_color)

func _top_entity(t: Tile):
	var best = null
	var best_p: int = -1
	for e in t.entities:
		var p: int = e.display_priority()
		if p > best_p:
			best_p = p
			best = e
	return best

func _entity_key(e) -> String:
	if e is Survivor:
		return "survivor:lead" if e.is_lead else "survivor:recruit"
	if e is ZombieUnit:
		return "zombie:" + e.unit_id
	if e is Npc:
		return "npc:" + e.faction_id
	return "survivor:recruit"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := _coord_at(event.position)
		if c != hover_cell:
			hover_cell = c
			tile_hovered.emit(c)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := _coord_at(event.position)
		if c.x >= 0:
			tile_clicked.emit(c)

func _coord_at(p: Vector2) -> Vector2i:
	var c := Vector2i(int(p.x / CELL_SIZE), int(p.y / CELL_SIZE))
	if GameState.grid == null or not GameState.grid.in_bounds(c):
		return Vector2i(-1, -1)
	return c
