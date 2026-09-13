extends Node
## Collection
## Tracks discovered pets / sizes / mutations (the Index).

signal collection_updated()

var _data: Dictionary = {}


func _ready() -> void:
        _data = SaveSystem.get_data()


func get_collection() -> Dictionary:
        return _data.get("collection", {"pets": [], "sizes": [], "mutations": []})

func get_pet_collection() -> Array:
        return get_collection().get("pets", [])

func get_size_collection() -> Array:
        return get_collection().get("sizes", [])

func get_mutation_collection() -> Array:
        return get_collection().get("mutations", [])

func has_pet(pet_id: String) -> bool:
        return pet_id in get_pet_collection()

func has_size(size_name: String) -> bool:
        return size_name in get_size_collection()

func has_mutation(mut_name: String) -> bool:
        return mut_name in get_mutation_collection()

func register_pet(pet_id: String) -> bool:
        var col: Dictionary = get_collection()
        var pets: Array = col.get("pets", [])
        if pet_id in pets:
                return false
        pets.append(pet_id)
        col["pets"] = pets
        _data["collection"] = col
        SaveSystem.mark_dirty()
        collection_updated.emit()
        return true

func register_size(size_name: String) -> bool:
        if size_name == "Normal":
                # Normal is always implicit
                return false
        var col: Dictionary = get_collection()
        var sizes: Array = col.get("sizes", [])
        if size_name in sizes:
                return false
        sizes.append(size_name)
        col["sizes"] = sizes
        _data["collection"] = col
        SaveSystem.mark_dirty()
        collection_updated.emit()
        return true

func register_mutation(mut_name: String) -> bool:
        if mut_name == "Normal":
                return false
        var col: Dictionary = get_collection()
        var muts: Array = col.get("mutations", [])
        if mut_name in muts:
                return false
        muts.append(mut_name)
        col["mutations"] = muts
        _data["collection"] = col
        SaveSystem.mark_dirty()
        collection_updated.emit()
        return true

func get_pet_index_progress() -> Dictionary:
        # Returns {discovered: int, total: int}
        var all := DataRegistry.get_all_pets().keys()
        return {"discovered": get_pet_collection().size(), "total": all.size()}

func get_size_index_progress() -> Dictionary:
        # Sizes: Tiny, Small, Normal, Large, Huge, Titanic
        var total: int = 6
        return {"discovered": get_size_collection().size() + 1, "total": total}

func get_mutation_index_progress() -> Dictionary:
        var total: int = 7  # Normal, Golden, Diamond, Rainbow, Shadow, Galaxy, Void
        return {"discovered": get_mutation_collection().size() + 1, "total": total}
