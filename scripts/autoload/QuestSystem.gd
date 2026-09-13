extends Node
## QuestSystem
## Loads quest definitions, tracks progress, and grants rewards.

signal quest_updated(quest_id: String, completed: bool)
signal quest_claimed(quest_id: String)

var _data: Dictionary = {}
var _quests: Array = []
var _by_id: Dictionary = {}


func _ready() -> void:
        _data = SaveSystem.get_data()
        _quests = DataRegistry.get_quests()
        for q in _quests:
                _by_id[q["id"]] = q
        # Ensure save has quest progress entries
        if not _data.has("quests"):
                _data["quests"] = []
        # Build runtime quest states (merge definitions with stored progress)
        _sync_quest_states()


func _sync_quest_states() -> void:
        # Stored quest states: array of {id, claimed, objectives: [{type, target, current}]}
        var stored: Array = _data.get("quests", [])
        var by_id: Dictionary = {}
        for s in stored:
                by_id[s["id"]] = s
        # Ensure each definition exists in stored
        var new_stored: Array = []
        for q in _quests:
                var qid: String = q["id"]
                if by_id.has(qid):
                        new_stored.append(by_id[qid])
                else:
                        var obj_copy: Array = []
                        for o in q.get("objectives", []):
                                obj_copy.append({
                                        "type": o["type"],
                                        "target": o["target"],
                                        "current": 0,
                                        "biome": o.get("biome", ""),
                                        "min_rarity": o.get("min_rarity", "")
                                })
                        new_stored.append({
                                "id": qid,
                                "claimed": false,
                                "objectives": obj_copy
                        })
        _data["quests"] = new_stored
        SaveSystem.mark_dirty()


func get_quest_states() -> Array:
        return _data.get("quests", [])

func get_quest_state(quest_id: String) -> Dictionary:
        for s in get_quest_states():
                if s["id"] == quest_id:
                        return s
        return {}

func is_quest_complete(quest_id: String) -> bool:
        var s := get_quest_state(quest_id)
        if s.is_empty():
                return false
        for o in s.get("objectives", []):
                if int(o.get("current", 0)) < int(o.get("target", 1)):
                        return false
        return true

func is_quest_claimed(quest_id: String) -> bool:
        var s := get_quest_state(quest_id)
        return bool(s.get("claimed", false))

func is_quest_available(quest_id: String) -> bool:
        var q: Dictionary = _by_id.get(quest_id, {})
        if q.is_empty():
                return false
        var prereq: String = q.get("prerequisite", "")
        if prereq.is_empty():
                return true
        return is_quest_claimed(prereq)

func progress_objective(objective_type: String, current_value: int) -> void:
        # For accumulating objectives (earn_money, reach_speed): we set current to the value directly
        for s in get_quest_states():
                if bool(s.get("claimed", false)):
                        continue
                for o in s.get("objectives", []):
                        if o["type"] == objective_type:
                                o["current"] = current_value
                                _check_quest_complete(s)
        quest_updated.emit("", false)

func increment_objective(objective_type: String, amount: int = 1, biome: String = "", rarity: String = "") -> void:
        # For counting objectives (collect_egg, hatch_pet)
        for s in get_quest_states():
                if bool(s.get("claimed", false)):
                        continue
                for o in s.get("objectives", []):
                        if o["type"] != objective_type:
                                continue
                        if objective_type == "enter_biome" and o.get("biome", "") != biome:
                                continue
                        if objective_type == "obtain_rarity":
                                var required_tier := DataRegistry.get_rarity_tier(o.get("min_rarity", ""))
                                var actual_tier := DataRegistry.get_rarity_tier(rarity)
                                if actual_tier < required_tier:
                                        continue
                        o["current"] = int(o.get("current", 0)) + amount
                        _check_quest_complete(s)
        quest_updated.emit("", false)

func _check_quest_complete(state: Dictionary) -> void:
        var all_done := true
        for o in state.get("objectives", []):
                if int(o.get("current", 0)) < int(o.get("target", 1)):
                        all_done = false
                        break
        if all_done:
                quest_updated.emit(state["id"], true)
                NotificationSystem.notify("Quest complete: %s" % _by_id.get(state["id"], {}).get("name", state["id"]), "quest", 3.0)
                AudioManager.play_sfx("quest_complete")

func claim_quest(quest_id: String) -> bool:
        if not is_quest_complete(quest_id) or is_quest_claimed(quest_id):
                return false
        var q: Dictionary = _by_id.get(quest_id, {})
        var rewards: Dictionary = q.get("rewards", {})
        if rewards.has("money"):
                Economy.add_money(int(rewards["money"]))
        if rewards.has("speed_xp"):
                Economy.add_speed_xp(int(rewards["speed_xp"]))
        for s in get_quest_states():
                if s["id"] == quest_id:
                        s["claimed"] = true
                        break
        SaveSystem.mark_dirty()
        quest_claimed.emit(quest_id)
        NotificationSystem.notify("Reward claimed!", "reward", 2.0)
        return true
