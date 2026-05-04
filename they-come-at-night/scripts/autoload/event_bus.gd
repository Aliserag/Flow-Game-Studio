extends Node

# Global signal hub. Decouples systems from each other.

signal day_advanced(day: int)
signal turn_advanced(turn: int)
signal player_moved(from_pos: Vector2i, to_pos: Vector2i)
signal entity_added(entity)
signal entity_removed(entity)
signal entity_moved(entity, from_pos: Vector2i, to_pos: Vector2i)
signal log_message(message: String, severity: String)
signal supplies_changed()
signal party_changed()
signal base_established(pos: Vector2i)
signal base_lost()
signal enhancement_built(id: String)
signal enhancement_progress(id: String, days_left: int)
signal swarm_warning(days_until: int, kind: String)
signal swarm_arrived(kind: String)
signal megahorde_unlocked(eta_days: int)
signal megahorde_arrived()
signal event_triggered(event_id: String)
signal event_resolved(event_id: String, choice_index: int)
signal combat_started(attacker, defender)
signal combat_resolved(attacker, defender, result: Dictionary)
signal game_over(victory: bool, summary: String)
signal hud_refresh_requested()
signal action_requested(action_id: String, payload: Dictionary)
signal request_event_modal(payload: Dictionary)
signal open_trade_request(npc_id: int)
signal modal_closed()

func log_info(msg: String) -> void:
	emit_signal("log_message", msg, "info")

func log_warn(msg: String) -> void:
	emit_signal("log_message", msg, "warn")

func log_danger(msg: String) -> void:
	emit_signal("log_message", msg, "danger")

func log_good(msg: String) -> void:
	emit_signal("log_message", msg, "good")
