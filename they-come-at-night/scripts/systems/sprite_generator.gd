class_name SpriteGenerator
extends RefCounted

# Procedural 32x32 sprite generator. Produces ImageTexture objects at runtime
# for terrains and entities so the game renders as actual pixel art rather than
# glyphs. Caches by key so we generate each sprite once per run.
#
# Replace any specific call site by setting `SpriteGenerator.override_texture(key, path)`
# to a hand-authored PNG when artist assets land.

const SIZE := 32

# Where the runtime sprite loader looks for hand-authored or AI-generated PNG
# overrides. File layout produced by tools/generate_sprites.py:
#   assets/sprites/terrain/<terrain_id>.png
#   assets/sprites/entities/zombie_<unit_id>.png
#   assets/sprites/entities/survivor_<variant>.png
#   assets/sprites/entities/npc_<faction_id>.png
const ASSET_TERRAIN_DIR := "res://assets/sprites/terrain/"
const ASSET_ENTITY_DIR := "res://assets/sprites/entities/"

static var _cache: Dictionary = {}    # key -> ImageTexture
static var _overrides: Dictionary = {} # key -> path to external PNG
static var _scanned: bool = false

static func override_texture(key: String, png_path: String) -> void:
	_overrides[key] = png_path
	_cache.erase(key)

# Scan asset folders once per run, populating _overrides for any slot with a
# matching PNG. Idempotent.
static func _scan_asset_overrides() -> void:
	if _scanned:
		return
	_scanned = true
	var td := DirAccess.open(ASSET_TERRAIN_DIR)
	if td != null:
		td.list_dir_begin()
		while true:
			var fname: String = td.get_next()
			if fname == "":
				break
			if td.current_is_dir() or not fname.ends_with(".png"):
				continue
			var slot: String = "terrain:" + fname.replace(".png", "")
			_overrides[slot] = ASSET_TERRAIN_DIR + fname
		td.list_dir_end()
	var ed := DirAccess.open(ASSET_ENTITY_DIR)
	if ed != null:
		ed.list_dir_begin()
		while true:
			var fname2: String = ed.get_next()
			if fname2 == "":
				break
			if ed.current_is_dir() or not fname2.ends_with(".png"):
				continue
			# zombie_single.png  →  zombie:single
			var base: String = fname2.replace(".png", "")
			var first_us: int = base.find("_")
			if first_us > 0:
				var slot2: String = base.substr(0, first_us) + ":" + base.substr(first_us + 1)
				_overrides[slot2] = ASSET_ENTITY_DIR + fname2
		ed.list_dir_end()

static func get_terrain_texture(terrain_id: String) -> ImageTexture:
	_scan_asset_overrides()
	var key := "terrain:" + terrain_id
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = _load_override_png(_overrides.get(key, ""))
	if tex != null:
		_cache[key] = tex
		return tex
	var image := _draw_terrain(terrain_id)
	var t := ImageTexture.create_from_image(image)
	_cache[key] = t
	return t

static func get_entity_texture(key: String) -> ImageTexture:
	_scan_asset_overrides()
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = _load_override_png(_overrides.get(key, ""))
	if tex != null:
		_cache[key] = tex
		return tex
	var image: Image = null
	if key.begins_with("zombie:"):
		image = _draw_zombie(key.replace("zombie:", ""))
	elif key.begins_with("survivor:"):
		image = _draw_survivor(key.replace("survivor:", ""))
	elif key.begins_with("npc:"):
		image = _draw_npc(key.replace("npc:", ""))
	else:
		image = _solid_image(Color(0.5, 0.5, 0.5))
	var t := ImageTexture.create_from_image(image)
	_cache[key] = t
	return t

# ---------- override loader ----------

# Loads an arbitrary PNG path into an ImageTexture. Returns null on miss.
# Accepts both `res://...` and raw `assets/sprites/...` paths.
static func _load_override_png(png_path: String) -> ImageTexture:
	if png_path == "":
		return null
	# Resource path → use load.
	if png_path.begins_with("res://") and ResourceLoader.exists(png_path):
		var res: Resource = load(png_path)
		if res is ImageTexture:
			return res
		if res is Texture2D:
			# Convert Texture2D-style imports into a plain ImageTexture.
			var img: Image = (res as Texture2D).get_image()
			if img != null:
				return ImageTexture.create_from_image(img)
	# Fall back: try opening as a file directly (covers PNGs added at runtime).
	if FileAccess.file_exists(png_path):
		var img2 := Image.new()
		var err: int = img2.load(png_path)
		if err == OK:
			return ImageTexture.create_from_image(img2)
	return null

# ---------- drawing primitives ----------

static func _new_image(bg: Color) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	return img

static func _solid_image(c: Color) -> Image:
	return _new_image(c)

static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			if ix >= 0 and ix < SIZE and iy >= 0 and iy < SIZE:
				img.set_pixel(ix, iy, c)

static func _stipple(img: Image, count: int, c: Color, seed: int) -> void:
	# Deterministic pseudo-random dots based on seed.
	var s: int = seed
	for _i in count:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var x: int = s % SIZE
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var y: int = s % SIZE
		img.set_pixel(x, y, c)

# ---------- terrain ----------

static func _draw_terrain(terrain_id: String) -> Image:
	var cfg: Dictionary = DataLoader.terrain.get(terrain_id, {})
	var hex: String = String(cfg.get("color", "#5a5a5a"))
	var base := Color(hex)
	var img := _new_image(base.darkened(0.1))
	var dark := base.darkened(0.4)
	var light := base.lightened(0.3)
	match terrain_id:
		"plains":
			# Sparse grass tufts.
			_stipple(img, 35, light, 11)
		"forest":
			# Tree trunks + canopies. Several small dark+green clumps.
			for clump_seed in [1, 7, 19, 23]:
				var s: int = (clump_seed * 1103515245 + 12345) & 0x7fffffff
				var cx: int = 6 + (s % 22)
				s = (s * 1103515245 + 12345) & 0x7fffffff
				var cy: int = 4 + (s % 22)
				_fill_rect(img, cx, cy, 4, 4, dark)
				_fill_rect(img, cx - 1, cy - 1, 6, 2, light)
		"road":
			# Horizontal stripes.
			_fill_rect(img, 0, 12, SIZE, 8, base.darkened(0.15))
			_fill_rect(img, 14, 15, 4, 2, light)
			_fill_rect(img, 22, 15, 4, 2, light)
		"ruins":
			# Broken brick pattern.
			for row in 4:
				for col in 3:
					var ox: int = col * 10 + (row % 2) * 5
					if row != 1 or col != 1:  # leave a gap
						_fill_rect(img, ox + 1, row * 7 + 2, 8, 5, dark)
		"house":
			# Wall with roof line.
			_fill_rect(img, 4, 8, 24, 22, dark)
			_fill_rect(img, 2, 6, 28, 4, base.darkened(0.5))
			# Door.
			_fill_rect(img, 14, 20, 4, 10, base.lightened(0.1))
			# Window.
			_fill_rect(img, 8, 12, 4, 4, light)
			_fill_rect(img, 20, 12, 4, 4, light)
		"supermarket":
			# Wide front with stripes.
			_fill_rect(img, 2, 4, 28, 24, dark)
			_fill_rect(img, 4, 8, 24, 4, light)
			_fill_rect(img, 4, 14, 24, 4, light)
			_fill_rect(img, 4, 20, 24, 4, light)
		"hospital":
			# Red cross on white wall.
			_fill_rect(img, 4, 4, 24, 24, Color(0.92, 0.88, 0.82))
			_fill_rect(img, 14, 8, 4, 16, Color(0.85, 0.15, 0.15))
			_fill_rect(img, 8, 14, 16, 4, Color(0.85, 0.15, 0.15))
		"military":
			# Sandbag wall + radio mast.
			_fill_rect(img, 0, 18, SIZE, 14, dark)
			for col in 4:
				_fill_rect(img, col * 8 + 2, 20, 6, 4, base.darkened(0.25))
			_fill_rect(img, 15, 0, 2, 18, light)
		"gas_station":
			# Two pumps under a flat roof.
			_fill_rect(img, 2, 4, 28, 4, dark)
			_fill_rect(img, 8, 10, 4, 18, light)
			_fill_rect(img, 20, 10, 4, 18, light)
		"church":
			# Steeple.
			_fill_rect(img, 12, 16, 8, 16, dark)
			_fill_rect(img, 14, 2, 4, 14, dark)
			_fill_rect(img, 13, 6, 6, 2, light)
		"junkyard":
			# Stacked metal hunks.
			_stipple(img, 80, dark, 5)
			_fill_rect(img, 4, 18, 8, 8, dark)
			_fill_rect(img, 16, 14, 10, 12, dark.darkened(0.3))
		"police_station":
			# Blue building with badge stripe.
			_fill_rect(img, 4, 4, 24, 24, dark)
			_fill_rect(img, 4, 14, 24, 4, Color(0.85, 0.85, 0.95))
			_fill_rect(img, 14, 18, 4, 10, light)
		"farm":
			# Furrows.
			for row in 4:
				_fill_rect(img, 2, row * 8 + 2, 28, 4, base.darkened(0.1 + 0.05 * row))
			_stipple(img, 24, light, 13)
		_:
			_stipple(img, 20, light, 3)
	# 1-pixel border so adjacent tiles are visually separable.
	for i in SIZE:
		img.set_pixel(i, 0, Color(0, 0, 0, 0.3))
		img.set_pixel(i, SIZE - 1, Color(0, 0, 0, 0.3))
		img.set_pixel(0, i, Color(0, 0, 0, 0.3))
		img.set_pixel(SIZE - 1, i, Color(0, 0, 0, 0.3))
	return img

# ---------- zombies ----------

static func _draw_zombie(unit_id: String) -> Image:
	var img := _new_image(Color(0, 0, 0, 0))
	var body := Color(0.30, 0.50, 0.30)
	var dark_body := Color(0.18, 0.30, 0.18)
	match unit_id:
		"single":
			_draw_humanoid(img, 12, 8, 8, 16, body, dark_body, Color(0.6, 0.7, 0.5))
		"group":
			_draw_humanoid(img, 6, 6, 8, 16, body, dark_body, Color(0.6, 0.7, 0.5))
			_draw_humanoid(img, 17, 8, 8, 16, dark_body, dark_body.darkened(0.2), Color(0.5, 0.6, 0.4))
		"horde":
			# Tightly-packed silhouettes.
			for col in 3:
				_draw_humanoid(img, col * 10 + 1, 6 + (col % 2) * 2, 8, 18, body, dark_body, Color(0.5, 0.6, 0.4))
		"swarm":
			# Many small bodies.
			for col in 4:
				for row in 2:
					_fill_rect(img, col * 8, row * 14 + 2, 6, 12, body if (col + row) % 2 == 0 else dark_body)
		"megahorde":
			# Wall of darkness.
			_fill_rect(img, 0, 4, SIZE, SIZE - 4, dark_body.darkened(0.2))
			_stipple(img, 40, body, 17)
			_fill_rect(img, 14, 14, 4, 4, Color(0.9, 0.1, 0.1))  # bright eyes
		_:
			_draw_humanoid(img, 12, 8, 8, 16, body, dark_body, Color(0.6, 0.7, 0.5))
	return img

static func _draw_humanoid(img: Image, x: int, y: int, w: int, h: int,
		body_color: Color, leg_color: Color, head_color: Color) -> void:
	# Head.
	_fill_rect(img, x + w / 4, y, w / 2, w / 2, head_color)
	# Torso.
	_fill_rect(img, x, y + w / 2, w, h * 2 / 3 - w / 2, body_color)
	# Legs.
	_fill_rect(img, x, y + h * 2 / 3, w / 2 - 1, h / 3, leg_color)
	_fill_rect(img, x + w / 2 + 1, y + h * 2 / 3, w / 2 - 1, h / 3, leg_color)

# ---------- survivors ----------

static func _draw_survivor(variant: String) -> Image:
	var img := _new_image(Color(0, 0, 0, 0))
	var skin := Color(0.92, 0.78, 0.62)
	var body_color: Color
	var leg_color: Color
	var marker: Color = Color(0, 0, 0, 0)
	match variant:
		"lead":
			body_color = Color(0.78, 0.55, 0.25)  # warm tan
			leg_color = Color(0.35, 0.30, 0.20)
			marker = Color(0.95, 0.82, 0.20)  # gold star
		"recruit":
			body_color = Color(0.45, 0.40, 0.55)
			leg_color = Color(0.25, 0.22, 0.30)
		_:
			body_color = Color(0.50, 0.50, 0.50)
			leg_color = Color(0.30, 0.30, 0.30)
	_draw_humanoid(img, 12, 6, 8, 20, body_color, leg_color, skin)
	if marker.a > 0:
		# Gold marker above the head.
		_fill_rect(img, 14, 0, 4, 4, marker)
	return img

# ---------- NPCs (faction-tinted) ----------

static func _draw_npc(faction_id: String) -> Image:
	var img := _new_image(Color(0, 0, 0, 0))
	var faction: Dictionary = DataLoader.factions.get(faction_id, {})
	var alignment: String = String(faction.get("alignment", "neutral"))
	var body_color: Color
	var leg_color := Color(0.20, 0.18, 0.16)
	match alignment:
		"hostile": body_color = Color(0.50, 0.20, 0.20)
		"lawful":  body_color = Color(0.25, 0.40, 0.55)
		_:         body_color = Color(0.55, 0.50, 0.40)
	_draw_humanoid(img, 12, 6, 8, 20, body_color, leg_color, Color(0.85, 0.72, 0.55))
	# Question-mark hat strip (unrevealed = neutral tan band).
	_fill_rect(img, 12, 4, 8, 2, Color(0.95, 0.85, 0.40))
	return img
