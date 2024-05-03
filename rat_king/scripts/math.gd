class_name Math

### randomness

static func rnd_np() -> int:
	return -1 if randf() < 0.5 else 1

### numbers

static func repeat(t, length):
	return t - floor(t / length) * length

static func repeati(t: int, length: int) -> int:
	return t - floori(t / float(length)) * length

static func repeatf(t: float, length: float) -> float:
	return t - floorf(t / length) * length

static func repeati_array(t: int, array: Array) -> int:
	if not array: return 0
	return t - floor(t / float(array.size())) * array.size()

### directions

static func get_right(node: Node3D) -> Vector3:
	return node.get_global_transform().basis.x

static func get_left(node: Node3D) -> Vector3:
	return -node.get_global_transform().basis.x

static func get_up(node: Node3D) -> Vector3:
	return node.get_global_transform().basis.y

static func get_down(node: Node3D) -> Vector3:
	return -node.get_global_transform().basis.y

static func get_forward(node: Node3D) -> Vector3:
	return -node.get_global_transform().basis.z

static func get_back(node: Node3D) -> Vector3:
	return node.get_global_transform().basis.z
	
### vectors

static func vec2_lerp(a: Vector2, b: Vector2, t: Vector2) -> Vector2:
	return Vector2(lerpf(a.x, b.x, t.x), lerpf(a.y, b.y, t.y))

static func vec2_with_x(vec: Vector2, x: float) -> Vector2:
	return Vector2(x, vec.y)

static func vec2_with_y(vec: Vector2, y: float) -> Vector2:
	return Vector2(vec.x, y)

static func vec2_add_x(vec: Vector2, x: float) -> Vector2:
	return Vector2(vec.x + x, vec.y)

static func vec2_add_y(vec: Vector2, y: float) -> Vector2:
	return Vector2(vec.x, vec.y + y)
	
#

static func vec3_lerp(a: Vector3, b: Vector3, t: Vector3) -> Vector3:
	return Vector3(lerpf(a.x, b.x, t.x), lerpf(a.y, b.y, t.y), lerpf(a.z, b.z, t.z))

static func vec3_with_x(vec: Vector3, x: float) -> Vector3:
	return Vector3(x, vec.y, vec.z)

static func vec3_with_y(vec: Vector3, y: float) -> Vector3:
	return Vector3(vec.x, y, vec.z)

static func vec3_with_z(vec: Vector3, z: float) -> Vector3:
	return Vector3(vec.x, vec.y, z)

static func vec3_add_x(vec: Vector3, x: float) -> Vector3:
	return Vector3(vec.x + x, vec.y, vec.z)

static func vec3_add_y(vec: Vector3, y: float) -> Vector3:
	return Vector3(vec.x, vec.y + y, vec.z)

static func vec3_add_z(vec: Vector3, z: float) -> Vector3:
	return Vector3(vec.x, vec.y, vec.z + z)

### frame independent lerping

static func frin_lerpf(a: float, b: float, t: float, delta: float, hertz := 60.0) -> float:
	t = (1.0 - t) ** (delta * hertz)
	return t * a + (1.0 - t) * b

static func vec3_frin_lerp(a: Vector3, b: Vector3, t: float, delta: float, hertz := 60.0) -> Vector3:
	t = (1.0 - t) ** (delta * hertz)
	return Vector3(t * a.x + (1.0 - t) * b.x, t * a.y + (1.0 - t) * b.y, t * a.z + (1.0 - t) * b.z)

### smooth damping

# from https://github.com/Unity-Technologies/UnityCsReference/blob/master/Runtime/Export/Math/Mathf.cs
static func smooth_damp(cur: float, target: float, cur_velocity: Array[float], smooth_time: float, delta_time: float, maxSpeed := INF) -> float:
	smooth_time = maxf(0.0001, smooth_time)
	var omega := 2.0 / smooth_time
	var x := omega * delta_time
	var exp := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var original_to := target
	var max_change := maxSpeed * smooth_time
	var change := clampf(cur - target, -max_change, max_change)
	target = cur - change
	var temp := (cur_velocity[0] + omega * change) * delta_time
	cur_velocity[0] = (cur_velocity[0] - omega * temp) * exp
	var result := target + (change + temp) * exp
	if (original_to - cur > 0.0) == (result > original_to):
		result = original_to
		cur_velocity[0] = 0.0
	return result
	
# TODO: https://github.com/Unity-Technologies/UnityCsReference/blob/master/Runtime/Export/Math/Vector3.cs
