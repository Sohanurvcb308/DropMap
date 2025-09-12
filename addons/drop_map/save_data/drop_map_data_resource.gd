@tool
class_name DropMapDataResource extends Resource

const SAVE_PATH = "res://addons/drop_map/save_data/drop_map_data.tres"

@export var collections: Array[SceneCollectionData] = []
@export var active_collection = null
var active_scene: PackedScene: 
	get:
		if active_collection == null: return null 
		return active_collection.active_scene

static var _instance : DropMapDataResource = null

func _init():
	# Only allow one instance
	if _instance != null and _instance != self:
		push_error("DropMapData is a singleton! Use DropMapDataResource.get_instance() instead of creating new instances.")
		return
		
static func get_instance() -> DropMapDataResource:
	if _instance == null:
		if ResourceLoader.exists(SAVE_PATH):
			_instance = ResourceLoader.load(SAVE_PATH)
			if _instance.collections.size() != 0:
				_instance.active_collection = _instance.collections[0]
		else:
			_instance = DropMapDataResource.new()
	return _instance

# Helper function to add a new collection
func add_collection(collection_name: String) -> SceneCollectionData:
	var new_collection = SceneCollectionData.new(collection_name)
	collections.append(new_collection)
	save()
	return new_collection
	
func add_scene_to_collection(packed_scene: PackedScene):
	active_collection.scenes.append(packed_scene)
	save()
	
func remove_scene_from_collection(packed_scene: PackedScene):
	active_collection.scenes.erase(packed_scene)
	if active_collection.active_scene == packed_scene:
		active_collection.active_scene = null
	save()

func remove_active_scene_from_collection():
	active_collection.scenes.erase(active_scene)
	if active_collection.scenes.size() > 0:
		active_collection.active_scene = active_collection.scenes[0]
	else:
		active_collection.active_scene = null
	save()

func set_active_scene(packed_scene):
	active_collection.active_scene = packed_scene
	save()
	
func set_active_scene_collection(scene_collection: SceneCollectionData):
	if collections.has(scene_collection):
		active_collection = scene_collection
	else:
		printerr("DropMap: Tried to select a scene collection that doesnt exist")
		
func remove_active_collection():
	collections.erase(active_collection)
	active_collection = null
	save()

func rename_active_collection(new_name: String):
	active_collection.name = new_name
	save()
	
func save():
	var error = ResourceSaver.save(self, SAVE_PATH)
	if error != OK:
		print("Error saving collection: ", error)
		return
