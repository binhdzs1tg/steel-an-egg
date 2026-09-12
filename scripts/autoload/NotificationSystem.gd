extends Node
## NotificationSystem
## Queues toast-style notifications on the HUD. Auto-dismisses after duration.
## Also feeds the activity log on the HUD.

signal notification_raised(text: String, icon: String, duration: float)
signal log_message(text: String)

var _queue: Array = []
var _active_count: int = 0
const MAX_ACTIVE: int = 4


func notify(text: String, icon: String = "info", duration: float = 2.5) -> void:
	notification_raised.emit(text, icon, duration)
	log_message.emit(text)


func info(text: String, duration: float = 2.0) -> void:
	notify(text, "info", duration)


func money(amount: int, duration: float = 1.5) -> void:
	var prefix := "+" if amount >= 0 else ""
	notify("%s$%d" % [prefix, amount], "money", duration)


func log_msg(text: String) -> void:
	log_message.emit(text)
