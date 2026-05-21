class_name SpriteComposer
extends RefCounted
## Loads and composites layered orc/enemy sprites.
## Layers (in Z-order, painted bottom to top):
##   0. base body            (assets/chars/char_<arch>_base_idle.png)
##   1. scar overlay (if any) (assets/chars/scars/char_scar_<N>.png)
##   2. gear overlays         (assets/chars/gear/char_gear_<slot>_<gear_id>.png)
##
## Returns a Texture2D ready for a TextureRect or Sprite2D.
## All compositing happens on the CPU via Image — generated once, then cached.

const BASE_DIR := "res://assets/chars/"
const GEAR_DIR := "res://assets/chars/gear/"
const SCAR_DIR := "res://assets/chars/scars/"
const ENEMY_DIR := "res://assets/enemies/"

static var _cache: Dictionary = {}  # key (String) -> ImageTexture


static func get_orc_sprite(orc: Orc) -> Texture2D:
	## Returns a composited Texture2D for the given orc with its current gear and scars.
	var key: String = _orc_cache_key(orc)
	if _cache.has(key):
		return _cache[key]
	var base_path: String = BASE_DIR + "char_%s_base_idle.png" % orc.archetype_id
	var base_img: Image = _load_image(base_path)
	if base_img == null:
		return _fallback_texture(orc.archetype_id)
	# Apply scar overlay
	if orc.scars > 0:
		var scar_n: int = min(orc.scars, 3)
		var scar_img: Image = _load_image(SCAR_DIR + "char_scar_%d.png" % scar_n)
		if scar_img != null:
			_blend_into(base_img, scar_img)
	# Apply gear overlays in slot order: chest, offhand, accessory, weapon, head
	var slot_order := ["chest", "offhand", "accessory", "weapon", "head"]
	for slot: String in slot_order:
		if not orc.equipped_gear.has(slot):
			continue
		var gear_id: String = String(orc.equipped_gear[slot])
		var overlay_path: String = GEAR_DIR + "char_gear_%s_%s.png" % [slot, gear_id]
		var overlay_img: Image = _load_image(overlay_path)
		if overlay_img != null:
			_blend_into(base_img, overlay_img)
	var tex: ImageTexture = ImageTexture.create_from_image(base_img)
	_cache[key] = tex
	return tex


static func get_enemy_sprite(enemy_id: String) -> Texture2D:
	var key := "enemy:" + enemy_id
	if _cache.has(key):
		return _cache[key]
	var path: String = ENEMY_DIR + "enemy_%s.png" % enemy_id
	var img: Image = _load_image(path)
	if img == null:
		return _fallback_texture(enemy_id)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func invalidate(orc: Orc) -> void:
	## Call after gear or scar changes to force re-composite next request.
	var key: String = _orc_cache_key(orc)
	_cache.erase(key)


static func clear_cache() -> void:
	_cache.clear()


static func _orc_cache_key(orc: Orc) -> String:
	var gear_parts: Array = []
	var slots: Array = orc.equipped_gear.keys()
	slots.sort()
	for slot: String in slots:
		gear_parts.append("%s=%s" % [slot, String(orc.equipped_gear[slot])])
	return "orc:%s:scars=%d:%s" % [orc.archetype_id, orc.scars, ",".join(gear_parts)]


static func _load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	return tex.get_image()


static func _blend_into(base: Image, overlay: Image) -> void:
	## Standard alpha compositing of overlay onto base. Sizes may differ —
	## the overlay is anchored at top-left of the base.
	var w := min(base.get_width(), overlay.get_width())
	var h := min(base.get_height(), overlay.get_height())
	for y in h:
		for x in w:
			var ov_pixel: Color = overlay.get_pixel(x, y)
			if ov_pixel.a > 0.01:
				base.set_pixel(x, y, ov_pixel)


static func _fallback_texture(label: String) -> Texture2D:
	## Generates a magenta placeholder if the real sprite is missing.
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 1))
	return ImageTexture.create_from_image(img)
