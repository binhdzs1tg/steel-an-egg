extends Node3D
class_name Base
## The player's home base. Holds: Hatch Station, Treadmill, multiple Upgrade Stations,
## and a Pet Display area.

func _ready() -> void:
        _build_nodes()


func _build_nodes() -> void:
        # Base floor (a stone circle / platform)
        var floor_mesh := MeshInstance3D.new()
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = 8.0
        cylinder.bottom_radius = 8.0
        cylinder.height = 0.2
        var fmat := StandardMaterial3D.new()
        fmat.albedo_color = Color(0.45, 0.4, 0.35)
        fmat.roughness = 0.9
        cylinder.material = fmat
        floor_mesh.mesh = cylinder
        floor_mesh.material_override = fmat
        add_child(floor_mesh)

        # Static body for floor
        var floor_body := StaticBody3D.new()
        var col := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = 8.0
        shape.height = 0.2
        col.shape = shape
        col.position = Vector3(0, -0.1, 0)
        floor_body.add_child(col)
        add_child(floor_body)

        # Hatch station at north
        # (class_name instances already carry their script — no set_script needed)
        var hatch := HatchStation.new()
        hatch.position = Vector3(0, 0.1, -4.0)
        add_child(hatch)

        # Treadmill
        var tread := Treadmill.new()
        tread.position = Vector3(-3.5, 0.1, 2.0)
        add_child(tread)

        # Upgrade stations: speed, treadmill, pet_slots, egg_storage, base, income_boost
        var upgrades := ["speed", "treadmill", "pet_slots", "egg_storage", "base", "income_boost"]
        for i in range(upgrades.size()):
                var up := UpgradeStation.new()
                up.upgrade_id = upgrades[i]
                var angle := TAU * float(i) / float(upgrades.size())
                var radius := 6.0
                up.position = Vector3(cos(angle) * radius, 0.1, sin(angle) * radius)
                add_child(up)

        # Pet Display Area (center of base)
        var display := PetDisplayArea.new()
        display.position = Vector3(0, 0.1, 4.0)
        add_child(display)

        # "BASE" sign
        var sign := Label3D.new()
        sign.text = "BASE"
        sign.position = Vector3(0, 4.0, 0)
        sign.pixel_size = 0.025
        sign.font_size = 64
        sign.outline_size = 12
        sign.outline_modulate = Color.BLACK
        sign.modulate = Color(1.0, 0.85, 0.3)
        sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        add_child(sign)
