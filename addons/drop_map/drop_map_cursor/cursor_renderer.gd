@tool
extends Node

var space_state: PhysicsDirectSpaceState3D
var scene_instance: Node3D

const CURSOR_ADD_PATH = "res://addons/drop_map/drop_map_cursor/add_cursor.tscn"
const MAX_DISTANCE = 1000.0
const SURFACE_OFFSET = 0.1
const RAYCAST_HEIGHT = 100.0

var cursor_position: Vector3:
	get: return scene_instance.global_position

func _ready():
	set_cursor_scene(CURSOR_ADD_PATH, false)

func setup_physics():
	var current_scene = EditorInterface.get_edited_scene_root()
	if current_scene and current_scene.get_viewport():
		var world = current_scene.get_world_3d()
		if world:
			space_state = world.direct_space_state

func set_cursor_scene(path: String, visible: bool = false):
	if ResourceLoader.exists(path) == false:
		printerr("Invalid scene path for cursor preview."); return
	if scene_instance: scene_instance.queue_free()
	
	scene_instance = load(path).instantiate()
	if is_instance_valid(scene_instance) == false:
		printerr("Unexpected error initializing cursor preview scene."); return
				
	var editor_main_screen = EditorInterface.get_editor_main_screen()
	editor_main_screen.add_child(scene_instance)
	scene_instance.set_meta("_edit_lock_", true)
	
	var cursor = preload(CURSOR_ADD_PATH).instantiate()
	scene_instance.add_child(cursor)
	scene_instance.visible = visible
	

func handle_input(camera: Camera3D, event: InputEvent, closest_node: Node3D = null) -> bool:
	if event is InputEventMouseMotion:
		move_to_cursor(event.position, camera, closest_node)
		snap_to_floor(closest_node)
	return false  # Don't consume the event
	
func move_to_cursor(mouse_pos: Vector2, camera: Camera3D, exclude_node: Node3D = null):
	if not space_state: return
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * MAX_DISTANCE
	
	var query = build_query(from, to, exclude_node)
	var result = space_state.intersect_ray(query)
	
	if result:
		var target_position = result.position
		if result.has("normal"):
			target_position += result.normal * SURFACE_OFFSET
		scene_instance.global_position = target_position
	
func snap_to_floor(exclude_node: Node3D = null):
	var points: Array[Vector3] = []
	
	var start_pos = cursor_position + Vector3(0.0, RAYCAST_HEIGHT, 0)
	var end_pos = start_pos + Vector3(0, -RAYCAST_HEIGHT * 2, 0)
	var current_pos = start_pos
	
	# Collect all collision points along the raycast
	while current_pos.y > end_pos.y:
		var query = build_query(current_pos, end_pos, exclude_node)
		add_query_exclusion_node(query, exclude_node)
		
		var result = space_state.intersect_ray(query)
		if result.is_empty(): break

		points.append(result.position)
		current_pos = result.position + Vector3(0, -0.01, 0)
	
	if points.is_empty(): return
	points.sort_custom(func(a, b): return a.y > b.y)
	scene_instance.global_position.y = points[0].y
	
func build_query(from, to, exclude_node):
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	add_query_exclusion_node(query, exclude_node)
	return query
	
func add_query_exclusion_node(query, exclude_node: Node3D):
	var exclude_list = []
	var stack = [scene_instance]
	if exclude_node: stack.append(exclude_node)
	
	while stack.size() > 0:
		var current = stack.pop_back()
		if current is CollisionObject3D:
			exclude_list.append(current.get_rid())
		for child in current.get_children():
			if child is Node:
				stack.append(child)
	query.exclude = exclude_list
	
func cleanup():
	if scene_instance:
		scene_instance.queue_free()
