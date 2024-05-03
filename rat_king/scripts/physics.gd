class_name Physics

static var _tree: SceneTree
static var _world_3d: World3D

## only call these during _physics_process

###

static func set_tree(tree: SceneTree, world_3d: World3D) -> void:
	_tree = tree
	_world_3d = world_3d

###

# coroutine
static func wait_for() -> void:
	if not Engine.is_in_physics_frame():
		await _tree.physics_frame

###

## local to this node, even the direction!
static func ray_cast(node: Node3D, from: Vector3, dir: Vector3) -> Dictionary:
	if node == null: printerr("Trying to cast without node"); return {}
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.hit_back_faces = false
	ray_query.from = node.to_global(from)
	ray_query.to = node.to_global(from + dir)
	return node.get_world_3d().direct_space_state.intersect_ray(ray_query)

## local to this node, even the direction!
static func line_cast(node: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	if node == null: printerr("Trying to cast without node"); return {}
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.hit_back_faces = false
	ray_query.from = node.to_global(from)
	ray_query.to = node.to_global(to)
	return node.get_world_3d().direct_space_state.intersect_ray(ray_query)

## local to this node, even the direction!
static func shape_cast(node: Node3D, shape: Shape3D, from: Vector3, dir: Vector3, basis := Basis(), mask := 0xFFFFFFFF) -> float:
	if node == null or shape == null: printerr("Trying to cast without node or shape"); return -1.0
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(basis, node.to_global(from))
	shape_query.margin = shape.margin
	shape_query.motion = node.to_global(from + dir) - shape_query.transform.origin
	shape_query.collide_with_areas = false 
	shape_query.collision_mask = mask
	var motion := node.get_world_3d().direct_space_state.cast_motion(shape_query)
	return motion[0]

static func is_shape_intersecting(node: Node3D, shape: Shape3D, pos: Vector3, basis := Basis(), mask := 0xFFFFFFFF) -> Array[Dictionary]:
	if node == null or shape == null: printerr("Trying to cast without node or shape"); return []
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(basis, pos)
	shape_query.margin = shape.margin
	shape_query.collide_with_areas = false
	shape_query.collision_mask = mask	
	return node.get_world_3d().direct_space_state.intersect_shape(shape_query)

###

## global position and direction
static func world_3d_ray_cast(from: Vector3, dir: Vector3, mask := 0xFFFFFFFF) -> Dictionary:
	if _world_3d == null: printerr("Trying to cast without world"); return {}
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.hit_back_faces = false
	ray_query.from = from
	ray_query.to = from + dir
	ray_query.collide_with_areas = false 
	ray_query.collision_mask = mask
	return _world_3d.direct_space_state.intersect_ray(ray_query)

## global position and direction
static func world_3d_line_cast(from: Vector3, to: Vector3, mask := 0xFFFFFFFF) -> Dictionary:
	if _world_3d == null: printerr("Trying to cast without world"); return {}
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.hit_back_faces = false
	ray_query.from = from
	ray_query.to = to
	ray_query.collide_with_areas = false 
	ray_query.collision_mask = mask
	return _world_3d.direct_space_state.intersect_ray(ray_query)

## global position and direction
static func world_3d_shape_cast(shape: Shape3D, from: Vector3, dir: Vector3, basis := Basis(), mask := 0xFFFFFFFF) -> float:
	if _world_3d == null: printerr("Trying to cast without world"); return -1.0
	if shape == null: printerr("Trying to cast without shape"); return -1.0
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(basis, from)
	shape_query.margin = shape.margin
	shape_query.motion = dir
	shape_query.collide_with_areas = false 
	shape_query.collision_mask = mask
	var motion := _world_3d.direct_space_state.cast_motion(shape_query)
	return motion[0]

static func world_3d_is_shape_intersecting(shape: Shape3D, pos: Vector3, basis := Basis(), mask := 0xFFFFFFFF) -> Array[Dictionary]:
	if _world_3d == null: printerr("Trying to cast without world"); return []
	if shape == null: printerr("Trying to cast without shape"); return []
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(basis, pos)
	shape_query.margin = shape.margin
	shape_query.collide_with_areas = false
	shape_query.collision_mask = mask
	return _world_3d.direct_space_state.intersect_shape(shape_query)
