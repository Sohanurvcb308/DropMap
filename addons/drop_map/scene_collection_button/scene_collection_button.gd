@tool
extends Button

var collection: SceneCollectionData

signal selected_scene_collection(collection: SceneCollectionData)

func setup(scene_collection: SceneCollectionData, pressed: bool):
	collection = scene_collection
	text = scene_collection.name
	button_pressed = pressed

func _on_pressed() -> void:
	selected_scene_collection.emit(collection)
