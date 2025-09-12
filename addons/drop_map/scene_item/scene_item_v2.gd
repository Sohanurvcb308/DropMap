@tool
extends Control

@onready var preview_texture = %PreviewTexture
@onready var scene_name_label = %SceneNameLabel
@onready var activate_button = $ActivateButton

var packed_scene: PackedScene

signal item_activated(packed_scene : PackedScene)

func setup(scene: PackedScene, pressed: bool):
	packed_scene = scene
	activate_button.button_pressed = pressed
	_update_display()
	_load_preview()

func _update_display():
	if not packed_scene:
		return
	
	if not scene_name_label:
		return
	# Set scene name and path
	var scene_name = _get_scene_name()
	var scene_path = packed_scene.resource_path
	
	scene_name_label.text = scene_name

func _get_scene_name() -> String:
	if packed_scene.resource_path != "":
		return packed_scene.resource_path.get_file().get_basename()
	return "Unnamed Scene"

func _load_preview():
	# Try to get preview from EditorInterface
	var editor_resource_preview = EditorInterface.get_resource_previewer()
	if editor_resource_preview:
		editor_resource_preview.queue_resource_preview(
			packed_scene.resource_path,
			self,
			"_on_preview_ready",
			null
		)
	else:
		_set_default_preview()
		
func _on_preview_ready(path: String, preview: Texture2D, thumbnail: Texture2D, user_data):
	if not preview_texture:
		return
	if preview:
		preview_texture.texture = preview
	elif thumbnail:
		preview_texture.texture = thumbnail
	else:
		_set_default_preview()

func _set_default_preview():
	var editor_theme = EditorInterface.get_editor_theme()
	if editor_theme:
		preview_texture.texture = editor_theme.get_icon("PackedScene", "EditorIcons")

func _on_activate_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		item_activated.emit(packed_scene)
