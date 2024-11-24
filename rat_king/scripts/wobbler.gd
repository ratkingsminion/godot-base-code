class_name Wobbler
extends Node

enum Type { SCALE, ROTATE }

class Wobble:
	var type: Type
	var target: Node
	var factor := 0.0
	var seconds := 1.0
	var start_seconds := 1.0
	var strength := 1.0
	var max_strength := 1.5
	var original_scale # can be vector3 or vector2
	var original_rotation # can be vector3 or float
	var start_time := 0.0
	var speed := 1.0
	var axis # can be vector3 or vector2

static var _inst: Wobbler
static var _cur_wobbles: Array[Wobble] = []

###

func _process(delta: float) -> void:
	for idx: int in range(_cur_wobbles.size() - 1, -1, -1):
		var wobble := _cur_wobbles[idx]
		
		if wobble == null or not is_instance_valid(wobble.target):
			_cur_wobbles.remove_at(idx)
			continue
		
		var time := Helpers.cur_time(wobble.speed)
		wobble.seconds -= delta
		var target_factor = clampf(wobble.seconds / wobble.start_seconds, 0.0, 1.0)
		wobble.factor = move_toward(wobble.factor, target_factor, delta * 10.0)
		
		if wobble.factor <= 0.0 and wobble.seconds <= 0.0:
			wobble.target.scale = wobble.original_scale
			wobble.target.rotation = wobble.original_rotation
			_cur_wobbles.remove_at(idx)
			continue
		
		if wobble.type == Type.SCALE:
			var original_scale = wobble.original_scale
			var scale := lerpf(1.0,
				remap(sin(wobble.start_time + 20.0 * time), -1.0, 1.0, lerpf(1.0, 0.75, wobble.strength), lerpf(1.0, 1.5, wobble.strength)),
				wobble.factor)
			if wobble.target is Node3D:
				wobble.target.scale = Math.vec3_lerp(original_scale, original_scale * scale, wobble.axis)
			else:
				wobble.target.scale = Math.vec2_lerp(original_scale, original_scale * scale, wobble.axis)
		
		elif wobble.type == Type.ROTATE:
			if wobble.target is Node3D:
				wobble.target.rotation = wobble.original_rotation
				wobble.target.rotate(wobble.axis, wobble.strength * wobble.factor * sin(wobble.start_time + 10 * time) * 0.5)
			# TODO target type Control

static func wobble_x(node: Node, strength := 1.0, seconds := 1.0, speed := 1.0, type := Type.SCALE) -> void:
	wobble(node, strength, seconds, speed, Vector3.RIGHT, type)

static func wobble_y(node: Node, strength := 1.0, seconds := 1.0, speed := 1.0, type := Type.SCALE) -> void:
	wobble(node, strength, seconds, speed, Vector3.UP, type)

static func wobble_z(node: Node, strength := 1.0, seconds := 1.0, speed := 1.0, type := Type.SCALE) -> void:
	wobble(node, strength, seconds, speed, Vector3.MODEL_FRONT, type)

static func wobble(node: Node, strength := 1.0, seconds := 1.0, speed := 1.0, axis := Vector3.ONE, type := Type.SCALE) -> Wobble:
	if not node or strength == 0.0 or seconds <= 0.0: 
		return
	
	if _inst == null:
		_inst = Wobbler.new()
		node.get_tree().current_scene.add_child.call_deferred(_inst, true)
	
	var list := _cur_wobbles.filter(func(w: Wobble) -> bool: return w.target == node and w.type == type)
	
	if list:
		list[0].seconds = seconds
		return list[0]
		
	var wobble := Wobble.new()
	wobble.type = type
	wobble.factor = 0.0
	wobble.target = node
	wobble.start_seconds = seconds
	wobble.seconds = seconds
	wobble.strength = strength
	wobble.original_scale = node.scale
	wobble.original_rotation = node.rotation
	wobble.start_time = randf() * PI
	wobble.speed = speed
	if node is Node3D: wobble.axis = axis
	else: wobble.axis = Vector2(axis.x, axis.y)
	_cur_wobbles.append(wobble)
	return wobble
