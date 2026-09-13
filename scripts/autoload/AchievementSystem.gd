extends Node
## AchievementSystem
## Watches stat changes and unlocks achievements when thresholds are met.

signal achievement_unlocked(achievement_id: String)

var _data: Dictionary = {}
var _achievements: Array = []
var _by_id: Dictionary = {}


func _ready() -> void:
        _data = SaveSystem.get_data()
        _achievements = DataRegistry.get_achievements()
        for a in _achievements:
                _by_id[a["id"]] = a
        if not _data.has("achievements"):
                _data["achievements"] = []
        SaveSystem.mark_dirty()


func is_unlocked(achievement_id: String) -> bool:
        return achievement_id in _data.get("achievements", [])


func get_unlocked() -> Array:
        return _data.get("achievements", [])


func check_all() -> void:
        var stats: Dictionary = _data.get("stats", {})
        for a in _achievements:
                if is_unlocked(a["id"]):
                        continue
                var stat_name: String = a["stat"]
                var target: int = int(a["target"])
                var current: int = int(stats.get(stat_name, 0))
                if current >= target:
                        unlock(a["id"])


func unlock(achievement_id: String) -> void:
        if is_unlocked(achievement_id):
                return
        var list: Array = _data.get("achievements", [])
        list.append(achievement_id)
        _data["achievements"] = list
        SaveSystem.mark_dirty()
        achievement_unlocked.emit(achievement_id)
        var a: Dictionary = _by_id.get(achievement_id, {})
        NotificationSystem.notify("Achievement: %s" % a.get("name", achievement_id), "achievement", 3.0)
        AudioManager.play_sfx("achievement")
        # Spawn VFX burst above the player
        if GameManager.player:
                VFXBurst.spawn_at(GameManager.player.get_parent(), GameManager.player.global_position + Vector3(0, 2.5, 0), Color(1.0, 0.85, 0.3), 80, 0.2, 5.0, 2.0)


# Update a stat. Triggers achievement checks automatically.
func set_stat(stat_name: String, value: int) -> void:
        var stats: Dictionary = _data.get("stats", {})
        stats[stat_name] = value
        _data["stats"] = stats
        SaveSystem.mark_dirty()
        check_all()


func increment_stat(stat_name: String, amount: int = 1) -> void:
        var stats: Dictionary = _data.get("stats", {})
        stats[stat_name] = int(stats.get(stat_name, 0)) + amount
        _data["stats"] = stats
        SaveSystem.mark_dirty()
        check_all()
