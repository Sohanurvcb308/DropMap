@tool
extends Node3D
class_name DropMap

# Advanced settings
@export var name_instances: bool = true
@export var instance_name_prefix: String = ""
@export var sensitivity: float = 1.0

@onready var DROP_MAP_DATA = DropMapDataResource.get_instance()
var moving_node = null
var target_node = null

# Material for the dots - unshaded and always on top
var dot_material: StandardMaterial3D
var dot_markers: Array[DotMarker] = []

func _ready():
	if Engine.is_editor_hint():
		set_meta("_edit_lock_", true)
		dot_material = DotMarker.get_material()
		
func instantiate_scene_at(pos: Vector3) -> Node:
	var packed_scene = DROP_MAP_DATA.active_scene
	if not packed_scene:
		push_error("SceneInstantiator: Packed scene is null")
		return null
	
	# Instantiate scene
	var instance = packed_scene.instantiate()
	if not instance:
		push_error("SceneInstantiator: Failed to instantiate scene")
		return null
	# Configure instance
	_configure_new_instance(instance, packed_scene)
	add_child(instance)
	instance.global_position = pos

	if Engine.is_editor_hint(): _set_editor_owner(instance)
	return instance

func _get_scene_name(packed_scene: PackedScene) -> String:
	if not packed_scene:
		return "None"
	
	var path = packed_scene.resource_path
	if path != "":
		return path.get_file().get_basename()
	else:
		return "Unnamed Scene"
		
func _configure_new_instance(instance: Node, packed_scene):
	if name_instances:
		var base_name = _get_scene_name(packed_scene)
		var instance_name = instance_name_prefix + base_name
		
		var counter = 1
		var final_name = instance_name
		while has_node(NodePath(final_name)):
			final_name = instance_name + str(counter)
			counter += 1
		
		instance.name = final_name
		
	if Engine.is_editor_hint():
		if packed_scene and packed_scene.resource_path != "":
			instance.scene_file_path = packed_scene.resource_path

func input_handle_dot_focus(event, camera):
	if event is InputEventMouseMotion && moving_node == null:
		target_node = find_closest_child_to_mouse(camera, event.position)
		focus_dot(target_node)
	return false

func input_handle_moving_node(event, target_position):
	if event is InputEventMouseMotion && moving_node:
		moving_node.global_position = target_position
		for dot_marker in dot_markers:
			dot_marker.update_position()
	return false
			
func input_handle_add_scene(event, target_position):
	if (event is InputEventMouseButton && 
		event.button_index == MOUSE_BUTTON_LEFT &&
		event.pressed ):
		instantiate_scene_at(target_position)
		return true # consume event
	return false

func input_handle_remove_scene(event):
	if (event is InputEventMouseButton && 
		event.button_index == MOUSE_BUTTON_LEFT &&
		event.pressed ):
		remove_dot_for(target_node)
		target_node.queue_free()
		return true
	return false

func input_handle_transform_scene(event):
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: moving_node = target_node 
		else: moving_node = null
		return true
	return false
	
func _set_editor_owner(node: Node):
	if not Engine.is_editor_hint():
		return
	var scene_root = get_tree().edited_scene_root
	if not scene_root:
		return

	if node.get_parent() == self:
		node.set_owner(scene_root)
		
func find_closest_child_to_mouse(camera, mouse_pos) -> Node3D:
	var closest_node: Node3D = null
	var closest_distance = 50.0 # RYE TODO: remove magic number

	for child in get_children():
		if child is Node3D:
			var screen_pos = camera.unproject_position(child.global_position)
			var distance = mouse_pos.distance_to(screen_pos)
			
			if distance < closest_distance:
				closest_distance = distance
				closest_node = child
	return closest_node
	
func remove_dot_for(node: Node3D):
	for dot_marker in dot_markers:
		if dot_marker.tracked_node == node:
			dot_marker.queue_free()
			dot_markers.erase(dot_marker)
			break

func clear_dot_markers():
	focus_dot(null)
	for dot_marker in dot_markers:
		dot_marker.free()
	dot_markers.clear()
	
func build_dot_markers():
	clear_dot_markers()
	call_deferred('_create_dot_markers')
			
func _create_dot_markers():
	for child in get_children():
		if child is Node3D:
			var dot_marker = DotMarker.new(child)
			dot_marker.set_material_override(dot_material)
			add_child(dot_marker)
			dot_marker.update_position()
			dot_markers.append(dot_marker)

func focus_dot(node: Node3D):
	for dot_marker: DotMarker in dot_markers:
		if node == dot_marker.tracked_node:
			dot_marker.set_focused()
		else:
			dot_marker.set_unfocused()

func build_removal_dot_markers():
	build_dot_markers()
	call_deferred("_apply_removal_style_to_dots")
	
func build_transform_dot_markers():
	build_dot_markers()
	call_deferred("_apply_transform_style_to_dots")

func _apply_removal_style_to_dots():
	for dot_marker in dot_markers:
		dot_marker.dot_mesh.material_override.albedo_color = Color.RED
	
func _apply_transform_style_to_dots():
	for dot_marker in dot_markers:
		dot_marker.dot_mesh.material_override.albedo_color = Color.ORANGE

class DotMarker extends Node3D:
	var dot_mesh: MeshInstance3D
	var tracked_node: Node3D
	var radius: float = 0.1
	static var _material: StandardMaterial3D = null
	
	func _init(tracked_node: Node3D):
		self.tracked_node = tracked_node
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = radius
		sphere_mesh.height = radius * 2.0
	
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = sphere_mesh
		dot_mesh = mesh_instance
		add_child(dot_mesh)
		
	func update_position():
		global_position = tracked_node.global_position
		
	func set_material_override(material):
		dot_mesh.material_override = material.duplicate()
		
	func set_focused():
		dot_mesh.material_override.albedo_color.a = 0.5
		dot_mesh.mesh.radius = radius*2
		dot_mesh.mesh.height = radius*4
	
	func set_unfocused():
		dot_mesh.material_override.albedo_color.a = 1.0
		dot_mesh.mesh.radius = radius
		dot_mesh.mesh.height = radius * 2.0
		
	static func get_material():
		if _material == null:
			_material = StandardMaterial3D.new()
			_material.flags_unshaded = true
			_material.flags_transparent = true
			_material.render_priority = 2
			_material.flags_do_not_receive_shadows = true
			_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_material.no_depth_test = true  # This makes it render above everything
			_material.albedo_color = Color.ORANGE
			_material.emission_enabled = true
			_material.emission = Color.ORANGE
			_material.sorting_offset = 1000.0
		return _material
