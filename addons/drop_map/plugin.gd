@tool
extends EditorPlugin

var dock_instance
var cursor_renderer
var drop_map_container: DropMap = null
var dock_button: Button = null

var DROP_MAP_DATA = DropMapDataResource.get_instance()

enum MODES { ADD, REMOVE, TRANSFORM }
var active_mode: MODES = MODES.ADD

func _enter_tree():
	# Add the custom node type
	add_custom_type(
		"DropMap", 
		"Node3D", 
		preload("res://addons/drop_map/DropMap.gd"), 
		preload("res://addons/drop_map/icons/Grid.svg") # Optional custom icon
	)

	dock_instance = preload("res://addons/drop_map/drop_map_dock/drop_map_dock.tscn").instantiate()
	dock_instance.active_scene_changed.connect(_on_active_scene_changed)
	call_deferred('setup_dock_mode_buttons')
	
	dock_button = add_control_to_bottom_panel(dock_instance, "DropMap")
	
	cursor_renderer = preload("res://addons/drop_map/drop_map_cursor/cursor_renderer.gd").new()
	add_child(cursor_renderer)
	
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_check_and_fix_gridmaps()
	
func _exit_tree():
	remove_custom_type("DropMap")
	remove_control_from_docks(dock_instance)

	if EditorInterface.get_selection().selection_changed.is_connected(_on_selection_changed):
		EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	
	if cursor_renderer:
		cursor_renderer.cleanup()
		cursor_renderer.queue_free()
		
func _handles(object):
	return true

func _forward_3d_gui_input(viewport_camera, event):
	var target_position = cursor_renderer.cursor_position
	var mode = active_mode
	
	if drop_map_container:
		if mode != MODES.ADD:
			drop_map_container.input_handle_dot_focus(event, viewport_camera)
		else:
			if drop_map_container.input_handle_add_scene(event, target_position):
				return true
			
		if mode == MODES.TRANSFORM:
			drop_map_container.input_handle_moving_node(event, target_position)
			if drop_map_container.input_handle_transform_scene(event):
				return true
		if mode == MODES.REMOVE:
			if drop_map_container.input_handle_remove_scene(event):
				return true
			
	if cursor_renderer && drop_map_container:
		var closest_node = null
		if mode == MODES.TRANSFORM:
			closest_node = drop_map_container.moving_node
		return cursor_renderer.handle_input(viewport_camera, event, closest_node)
	return false

func _on_active_scene_changed(path: String):
	if path == "":
		cursor_renderer.scene_instance.hide()
		return
	update_cursor_renderer()

func _on_selection_changed():
	if drop_map_container: drop_map_container.clear_dot_markers()
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	
	if drop_map_container && drop_map_container.is_inside_tree() == false: drop_map_container = null
	
	for node in selected_nodes:
		if node is DropMap:
			drop_map_container = node
			break
		drop_map_container = null
			
	if drop_map_container:
		dock_button.show()
		dock_button.emit_signal("toggled", true)
		await get_tree().process_frame
		drop_map_container.set_meta("_edit_lock_", true)
		_check_and_fix_gridmaps()
	else:
		dock_button.hide()
		dock_button.emit_signal("toggled", false)
		
	update_dot_markers()
	update_cursor_renderer()

func update_cursor_renderer():
	if is_instance_valid(cursor_renderer) == false: return
	
	if drop_map_container: cursor_renderer.setup_physics()
	
	var show_cursor = active_mode == MODES.ADD
	if DROP_MAP_DATA.active_scene == null:
		cursor_renderer.scene_instance.hide()
		return
	var active_scene_path = DROP_MAP_DATA.active_scene.resource_path
	cursor_renderer.set_cursor_scene(active_scene_path, show_cursor && drop_map_container)

func update_dot_markers():
	if drop_map_container == null: return
	
	if active_mode == MODES.ADD:
		drop_map_container.clear_dot_markers()
	elif active_mode == MODES.REMOVE:
		drop_map_container.build_removal_dot_markers()
	elif active_mode == MODES.TRANSFORM:
		drop_map_container.build_transform_dot_markers()

func setup_dock_mode_buttons():
	var dock = dock_instance
	dock.instance_mode_button.toggled.connect(func(pressed): if pressed: _active_mode_changed(MODES.ADD))
	dock.remove_mode_button.toggled.connect(func(pressed): if pressed: _active_mode_changed(MODES.REMOVE))
	dock.transform_mode_button.toggled.connect(func(pressed): if pressed: _active_mode_changed(MODES.TRANSFORM))
	
func _active_mode_changed(mode):
	active_mode = mode
	update_dot_markers()
	update_cursor_renderer()
	
##################
#  Fix GridMaps  #
##################
			
func _check_and_fix_gridmaps():
	var edited_scene = EditorInterface.get_edited_scene_root()
	if not edited_scene:
		return

	var gridmaps = _find_all_gridmaps(edited_scene)
	for gridmap in gridmaps:
		_fix_gridmap_collision(gridmap)

func _find_all_gridmaps(node: Node) -> Array[GridMap]:
	var gridmaps: Array[GridMap] = []
	if node is GridMap:
		gridmaps.append(node)
	for child in node.get_children():
		gridmaps.append_array(_find_all_gridmaps(child))
	return gridmaps

func _fix_gridmap_collision(gridmap: GridMap):
	var original_collision_layer = gridmap.collision_layer
	gridmap.collision_layer = 0
	await get_tree().process_frame
	gridmap.collision_layer = original_collision_layer
