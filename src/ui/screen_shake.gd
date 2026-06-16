class_name ScreenShake
## Shakes a Control or Node2D by jittering its position over N frames with
## linear decay back to the origin.
##
## Usage:
##   ScreenShake.shake(battle_area_node, 6.0, 10)
##
## The node's position is restored to its original value when the shake ends.
## Safe to call while a shake is already running — it will restart with new params.

## Shakes [param target] by up to [param intensity] pixels for [param frames] frames.
## Uses linear decay: full intensity on frame 1, zero on the final frame.
## [param scene_tree] must be provided so we can await process frames.
static func shake(target: Node, intensity: float, frames: int, scene_tree: SceneTree) -> void:
	if frames <= 0 or intensity <= 0.0:
		return

	var origin: Vector2 = _get_position(target)
	var f := frames

	while f > 0:
		var decay: float = float(f) / float(frames)  # 1.0 -> near 0
		var offset := Vector2(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity, intensity) * decay
		)
		_set_position(target, origin + offset)
		await scene_tree.process_frame
		f -= 1

	_set_position(target, origin)


static func _get_position(node: Node) -> Vector2:
	if node is Control:
		return (node as Control).position
	elif node is Node2D:
		return (node as Node2D).position
	return Vector2.ZERO


static func _set_position(node: Node, pos: Vector2) -> void:
	if node is Control:
		(node as Control).position = pos
	elif node is Node2D:
		(node as Node2D).position = pos
