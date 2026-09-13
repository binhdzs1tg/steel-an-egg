# GameManager.gd
# Singleton that orchestrates high-level game state: holds references to player/world,
# tracks the "carried egg" state, exposes helper signals.
extends Node

signal carried_egg_changed(egg_id: String)
signal game_state_changed(state: int)
signal day_tick(day: int)

enum GameState { EXPLORING, CARRYING, CHASE, PAUSED, GAME_OVER }

# --- World/player references (set when world instantiates them) ---
var _player: Node2D = null
var _world: Node2D = null

# --- High-level game state ---
var state: int = GameState.EXPLORING
var carried_egg_id: String = ""
var carried_egg_data: Dictionary = {}
var current_day: int = 1
var _day_time: float = 0.0
const DAY_LENGTH := 120.0  # seconds per in-game day

# --- Pending state from save file (loaded before world is built) ---
var _pending_player_state: Dictionary = {}
var _pending_world_state: Dictionary = {}


# ---------- Registration (called by world/player on _ready) ----------
func register_player(p: Node2D) -> void:
	_player = p
	if not _pending_player_state.is_empty() and p.has_method("deserialize"):
		p.deserialize(_pending_player_state)
		_pending_player_state.clear()


func register_world(w: Node2D) -> void:
	_world = w
	if not _pending_world_state.is_empty() and w.has_method("deserialize"):
		w.deserialize(_pending_world_state)
		_pending_world_state.clear()


func get_player() -> Node2D:
	return _player


func get_world() -> Node2D:
	return _world


# ---------- Pending save state ----------
func set_pending_player_state(state: Dictionary) -> void:
	_pending_player_state = state


func set_pending_world_state(state: Dictionary) -> void:
	_pending_world_state = state


# ---------- Carried egg ----------
func set_carried_egg(egg_id: String) -> void:
	carried_egg_id = egg_id
	carried_egg_data = DataRegistry.get_egg(egg_id)
	carried_egg_changed.emit(egg_id)
	if egg_id != "":
		state = GameState.CARRYING
	else:
		state = GameState.EXPLORING
	game_state_changed.emit(state)


func get_carried_egg_id() -> String:
	return carried_egg_id


func is_carrying_egg() -> bool:
	return carried_egg_id != ""


# ---------- Day/time tracking ----------
func _process(delta: float) -> void:
	if state == GameState.PAUSED or state == GameState.GAME_OVER:
		return
	_day_time += delta
	if _day_time >= DAY_LENGTH:
		_day_time = 0.0
		current_day += 1
		day_tick.emit(current_day)


# ---------- Pause ----------
func pause_game() -> void:
	if state == GameState.GAME_OVER:
		return
	state = GameState.PAUSED
	get_tree().paused = true
	game_state_changed.emit(state)


func resume_game() -> void:
	if state != GameState.PAUSED:
		return
	get_tree().paused = false
	state = GameState.EXPLORING if carried_egg_id == "" else GameState.CARRYING
	game_state_changed.emit(state)


func is_paused() -> bool:
	return state == GameState.PAUSED


# ---------- Reset (new game) ----------
func reset_for_new_game() -> void:
	_player = null
	_world = null
	state = GameState.EXPLORING
	carried_egg_id = ""
	carried_egg_data = {}
	current_day = 1
	_day_time = 0.0
	_pending_player_state = {}
	_pending_world_state = {}


# ---------- Helpers ----------
func get_player_speed() -> float:
	if _player == null:
		return 0.0
	return _player.get_current_speed()


func notify_chase_started() -> void:
	state = GameState.CARRYING  # we keep CARRYING during chase; UI shows different prompt
	game_state_changed.emit(state)
