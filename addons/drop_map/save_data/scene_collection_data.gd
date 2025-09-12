@tool
class_name SceneCollectionData extends Resource

@export var name: String
@export var scenes: Array[PackedScene] = [] # Stores an array of scene paths
@export var active_scene: PackedScene = null

func _init(_name := ""):
	name = _name
