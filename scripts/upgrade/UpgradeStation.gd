extends Node3D
class_name UpgradeStation
## An interactable station where the player buys upgrades.
## Each station sells one upgrade type (speed, treadmill, pet_slots, egg_storage, base, income_boost).

@export var upgrade_id: String = "speed"

var prompt_label: Label3D
var _orb: MeshInstance3D = null
var _last_prompt_text: String = ""


func _ready() -> void:
        _build_nodes()


func _build_nodes() -> void:
        # Base
        var base := MeshInstance3D.new()
        var base_mesh := BoxMesh.new()
        base_mesh.size = Vector3(1.5, 0.2, 1.5)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.3, 0.3, 0.35)
        mat.roughness = 0.7
        base.mesh = base_mesh
        base.material_override = mat
        add_child(base)

        # Pedestal
        var ped := MeshInstance3D.new()
        var ped_mesh := CylinderMesh.new()
        ped_mesh.top_radius = 0.4
        ped_mesh.bottom_radius = 0.4
        ped_mesh.height = 1.0
        var pmat := StandardMaterial3D.new()
        pmat.albedo_color = Color(0.5, 0.45, 0.4)
        ped.mesh = ped_mesh
        ped.material_override = pmat
        ped.position = Vector3(0, 0.6, 0)
        add_child(ped)

        # Orb on top (floating, glows with the upgrade color)
        var orb := MeshInstance3D.new()
        var orb_mesh := SphereMesh.new()
        orb_mesh.radius = 0.3
        orb_mesh.height = 0.6
        var omat := StandardMaterial3D.new()
        omat.albedo_color = _upgrade_color(upgrade_id)
        omat.emission_enabled = true
        omat.emission = _upgrade_color(upgrade_id)
        omat.emission_energy_multiplier = 0.7
        omat.roughness = 0.3
        orb.mesh = orb_mesh
        orb.material_override = omat
        orb.position = Vector3(0, 1.4, 0)
        orb.name = "Orb"
        add_child(orb)
        _orb = orb

        # Light removed for performance: the emissive orb already conveys the
        # upgrade color. 6 permanent omni lights around the Base cost a lot of
        # fill-rate in the Forward+ renderer for no visual benefit.

        # Prompt label
        prompt_label = Label3D.new()
        prompt_label.position = Vector3(0, 2.2, 0)
        prompt_label.pixel_size = 0.012
        prompt_label.font_size = 24
        prompt_label.outline_size = 6
        prompt_label.outline_modulate = Color.BLACK
        prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        add_child(prompt_label)

        # Static body for raycast
        var static_body := StaticBody3D.new()
        var s_col := CollisionShape3D.new()
        var s_shape := BoxShape3D.new()
        s_shape.size = Vector3(1.5, 2.0, 1.5)
        s_col.shape = s_shape
        s_col.position = Vector3(0, 1.0, 0)
        static_body.add_child(s_col)
        add_child(static_body)


func _upgrade_color(uid: String) -> Color:
        match uid:
                "speed": return Color(0.3, 0.8, 1.0)
                "treadmill": return Color(1.0, 0.5, 0.2)
                "pet_slots": return Color(0.9, 0.7, 0.2)
                "egg_storage": return Color(0.6, 0.9, 0.4)
                "base": return Color(0.7, 0.5, 0.9)
                "income_boost": return Color(0.2, 0.95, 0.4)
                _: return Color.WHITE


func _process(_delta: float) -> void:
        # Bob orb (cheap, always run)
        if _orb:
                _orb.position.y = 1.4 + sin(Time.get_ticks_msec() * 0.003) * 0.08
                _orb.rotation.y += _delta * 1.5
        # Update prompt ONLY when the text actually changed. Re-assigning
        # Label3D.text regenerates the text mesh; doing it 60x/s per station
        # (x6 stations) was a needless per-frame cost.
        var lvl := Economy.get_upgrade_level(upgrade_id)
        var max_lvl := Economy.get_upgrade_max_level(upgrade_id)
        var text: String
        var can_afford := false
        if lvl >= max_lvl:
                var def_max: Dictionary = DataRegistry.get_upgrade_def(upgrade_id)
                text = "%s MAX" % def_max.get("name", upgrade_id)
        else:
                var def: Dictionary = DataRegistry.get_upgrade_def(upgrade_id)
                var cost := Economy.get_upgrade_cost(upgrade_id)
                can_afford = Economy.get_money() >= cost
                text = "%s Lv.%d\n$%d\n[E] %s" % [def.get("name", upgrade_id), lvl, cost, "BUY" if can_afford else "Can't afford"]
        if text != _last_prompt_text:
                _last_prompt_text = text
                prompt_label.text = text
                prompt_label.modulate = Color(1, 1, 1) if can_afford else Color(0.7, 0.5, 0.5)


func get_prompt_text() -> String:
        var lvl := Economy.get_upgrade_level(upgrade_id)
        var max_lvl := Economy.get_upgrade_max_level(upgrade_id)
        var def: Dictionary = DataRegistry.get_upgrade_def(upgrade_id)
        var display_name: String = def.get("name", upgrade_id)
        if lvl >= max_lvl:
                return "%s MAX" % display_name
        var cost := Economy.get_upgrade_cost(upgrade_id)
        return "Upgrade %s Lv.%d -> %d ($%d)" % [display_name, lvl, lvl + 1, cost]


func interact(_player: Node) -> void:
        var lvl := Economy.get_upgrade_level(upgrade_id)
        var max_lvl := Economy.get_upgrade_max_level(upgrade_id)
        if lvl >= max_lvl:
                NotificationSystem.notify("Already at max level!", "info", 1.5)
                return
        var cost := Economy.get_upgrade_cost(upgrade_id)
        if Economy.get_money() < cost:
                NotificationSystem.notify("Not enough money! Need $%d" % cost, "warning", 2.0)
                return
        if Economy.purchase_upgrade(upgrade_id):
                NotificationSystem.notify("Upgrade purchased!", "upgrade", 2.0)
