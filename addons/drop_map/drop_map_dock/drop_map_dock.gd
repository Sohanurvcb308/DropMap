@tool
extends Control
class_name SceneInstantiatorDock

@onready var scene_list_container = %SceneListContainer
@onready var file_dialog = $FileDialog

# Mode Controls
@onready var instance_mode_button = %InstanceModeButton
@onready var remove_mode_button = %RemoveModeButton
@onready var transform_mode_button = %TransformModeButton

# Scene Collection Controls
@onready var collection_container = %CollectionContainer
@onready var new_collection_input = %NewCollectionInput
@onready var collection_controls = %CollectionControls

# Active Scene Controls
@onready var open_scene_button = %OpenSceneButton
@onready var remove_from_collection_button = %RemoveFromCollectionButton

@onready var no_scenes_info = %NoScenesInfo
@onready var DROP_MAP_DATA = DropMapDataResource.get_instance()

signal active_scene_changed(path: String)

func _ready():
	file_dialog.files_selected.connect(_on_files_selected)
	
	# Set up file dialog
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tscn", "Scene files")
	file_dialog.add_filter("*.scn", "Scene files (binary)")
	
	build_collection_ui()
	print("READY")
	print(DROP_MAP_DATA.active_scene)
	call_deferred("_refresh_scene_list")

func _refresh_scene_list():
	no_scenes_info.visible = scenes_info_visibility()
	for item in scene_list_container.get_children():
		item.queue_free()
	if DROP_MAP_DATA.active_collection:
		for scene in DROP_MAP_DATA.active_collection.scenes:
			_add_scene_item(scene)

func scenes_info_visibility():
	return DROP_MAP_DATA.active_collection == null || DROP_MAP_DATA.active_collection.scenes.size() == 0
	
func update_collection_controls(disabled: bool):
	for button in collection_controls.get_children():
		button.disabled = disabled

func _add_scene_item(packed_scene: PackedScene):
	var scene_item = preload("res://addons/drop_map/scene_item/scene_item_v2.tscn").instantiate()
	scene_list_container.add_child(scene_item)
	var is_active_item = packed_scene == DROP_MAP_DATA.active_scene
	if is_active_item: print(packed_scene.resource_path)
	scene_item.setup(packed_scene, is_active_item)

	scene_item.item_activated.connect(_on_item_activated)

func _on_files_selected(paths: PackedStringArray):
	for path in paths:
		var packed_scene = load(path) as PackedScene
		if packed_scene:
			DROP_MAP_DATA.add_scene_to_collection.call(packed_scene)
	
	_refresh_scene_list()
	
func _on_item_activated(scene_item_control: PackedScene):
	DROP_MAP_DATA.set_active_scene.call(scene_item_control)
	active_scene_changed.emit(scene_item_control.resource_path)
	update_active_scene_controls()

func _on_new_collection_input_text_submitted(new_text: String) -> void:
	new_collection_input.clear()
	DROP_MAP_DATA.add_collection.call(new_text)
	build_collection_ui()

func build_collection_ui():
	clear_loaded_collection_list()
	var collections = DROP_MAP_DATA.collections
	for collection in collections:
		var collection_button = preload("res://addons/drop_map/scene_collection_button/scene_collection_button.tscn").instantiate()
		collection_container.add_child(collection_button)
		var is_active = collection == DROP_MAP_DATA.active_collection
		collection_button.setup(collection, is_active)
		collection_button.selected_scene_collection.connect(_on_selected_scene_collection)
		
	update_collection_controls(DROP_MAP_DATA.active_collection == null)
	
func clear_loaded_collection_list():
	var children = collection_container.get_children() 
	for child in children:
		child.queue_free() 
			
func _on_selected_scene_collection(scene_collection: SceneCollectionData):
		DROP_MAP_DATA.set_active_scene_collection.call(scene_collection)
		build_collection_ui()
		_refresh_scene_list()
		var active_scene = DROP_MAP_DATA.active_collection.active_scene
		if active_scene:
			active_scene_changed.emit(active_scene.resource_path)
		else:
			active_scene_changed.emit("")
		update_active_scene_controls()
		

func _on_add_scene_button_pressed() -> void:
	file_dialog.popup_centered_ratio(0.5)

func _on_remove_collection_button_pressed() -> void:
	var confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.dialog_text = "Are you sure you want to remove this collection and it's scenes from DropMap?"
	confirmation_dialog.title = "Confirm Action"
	
	EditorInterface.get_base_control().add_child(confirmation_dialog)
	confirmation_dialog.confirmed.connect(_on_remove_collection_confirmed)
	
	confirmation_dialog.popup_centered()

func _on_remove_collection_confirmed():
	DROP_MAP_DATA.remove_active_collection.call()
	build_collection_ui()
	_refresh_scene_list()
	update_active_scene_controls()
	
func show_rename_popup():
	var dialog = AcceptDialog.new()
	var input = LineEdit.new()
	
	dialog.title = "Rename"
	input.text = DROP_MAP_DATA.active_collection.name
	input.select_all()
	
	dialog.add_child(input)
	add_child(dialog)
	
	dialog.confirmed.connect(func(): 
		DROP_MAP_DATA.rename_active_collection(input.text)
		build_collection_ui()
		dialog.queue_free()
	)
	
	dialog.popup_centered()
	input.grab_focus()
	
func update_active_scene_controls():
	var disabled = DROP_MAP_DATA.active_scene == null
	open_scene_button.disabled = disabled
	remove_from_collection_button.disabled = disabled

func _on_edit_collection_name_button_pressed() -> void:
	show_rename_popup()

func _on_open_scene_button_pressed() -> void:
	var scene = DROP_MAP_DATA.active_scene
	if scene == null: return
	
	var scene_path = scene.resource_path
	
	if not FileAccess.file_exists(scene_path):
		print("Error: Scene file does not exist: ", scene_path)
		return
	
	# Check if the file has a valid scene extension
	var valid_extensions = [".tscn", ".scn"]
	var file_extension = scene_path.get_extension().to_lower()
	if not ("." + file_extension) in valid_extensions:
		print("Error: File is not a valid scene file: ", scene_path)
		return
		
	var editor_interface = EditorInterface
	editor_interface.open_scene_from_path(scene_path)


func _on_remove_from_collection_button_pressed() -> void:
	DROP_MAP_DATA.remove_active_scene_from_collection()
	var active_scene_path = ""
	if DROP_MAP_DATA.active_scene:
		active_scene_path = DROP_MAP_DATA.active_scene.resource_path
	active_scene_changed.emit(active_scene_path)
	_refresh_scene_list()
	update_active_scene_controls()
