extends Node
## InputMapHelper
## Centralises input reading for the player and camera.
## Acts as a buffered layer between the InputMap and gameplay code.

func get_move_vector() -> Vector2:
	# Returns normalized 2D vector: x = strafe, y = forward/back (forward = -1)
	var v := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		v.y -= 1.0
	if Input.is_action_pressed("move_backward"):
		v.y += 1.0
	if Input.is_action_pressed("move_left"):
		v.x -= 1.0
	if Input.is_action_pressed("move_right"):
		v.x += 1.0
	return v.normalized()


func is_jump_pressed() -> bool:
	return Input.is_action_pressed("jump")


func is_shift_lock_held() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)
