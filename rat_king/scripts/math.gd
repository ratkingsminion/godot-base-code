class_name Math

### randomness

static func rnd_np() -> int:
	return -1 if randf() < 0.5 else 1

### numbers

static func wrapi_array(t: int, array: Array) -> int:
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

## uses radians
static func frin_lerp_angle(a: float, b: float, t: float, delta: float, hertz := 60.0) -> float:
	var dd := fposmod((b - a), TAU)
	if dd > PI: dd -= TAU
	return a + dd * (1.0 - ((1.0 - t) ** (delta * hertz)))

static func basis_frin_slerp(a: Basis, b: Basis, t: float, delta: float, hertz = 60.0) -> Basis:
	return a.orthonormalized().slerp(b.orthonormalized(), 1.0 - ((1.0 - t) ** (delta * hertz)))

### smooth damping

# from https://github.com/Unity-Technologies/UnityCsReference/blob/master/Runtime/Export/Math/Mathf.cs
static func smooth_damp(cur: float, target: float, cur_velocity: Array[float], smooth_time: float, delta_time: float, max_speed := INF) -> float:
	smooth_time = maxf(0.0001, smooth_time)
	var omega := 2.0 / smooth_time
	var x := omega * delta_time
	var expo := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var original_to := target
	var max_change := max_speed * smooth_time
	var change := clampf(cur - target, -max_change, max_change)
	target = cur - change
	var temp := (cur_velocity[0] + omega * change) * delta_time
	cur_velocity[0] = (cur_velocity[0] - omega * temp) * expo
	var result := target + (change + temp) * expo
	if (original_to - cur > 0.0) == (result > original_to):
		cur_velocity[0] = 0.0
		return original_to
	return result
	
# from https://github.com/Unity-Technologies/UnityCsReference/blob/master/Runtime/Export/Math/Vector3.cs
static func vec3_smooth_damp(cur: Vector3, target: Vector3, cur_velocity: Array[Vector3], smooth_time: float, delta_time: float, max_speed := INF) -> Vector3:
	var output_x := 0.0
	var output_y := 0.0
	var output_z := 0.0
	smooth_time = maxf(0.0001, smooth_time)
	var omega := 2.0 / smooth_time
	var x := omega * delta_time
	var expo := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change_x := cur.x - target.x
	var change_y := cur.y - target.y
	var change_z := cur.z - target.z
	var original_to := target
	var max_change := max_speed * smooth_time
	var max_change_sq := max_change * max_change
	var sqr_mag := change_x * change_x + change_y * change_y + change_z * change_z
	if sqr_mag > max_change_sq:
		var mag := sqrt(sqr_mag)
		change_x = change_x / mag * max_change
		change_y = change_y / mag * max_change
		change_z = change_z / mag * max_change
	target.x = cur.x - change_x;
	target.y = cur.y - change_y;
	target.z = cur.z - change_z;
	var temp_x := (cur_velocity[0].x + omega * change_x) * delta_time
	var temp_y := (cur_velocity[0].y + omega * change_y) * delta_time
	var temp_z := (cur_velocity[0].z + omega * change_z) * delta_time
	cur_velocity[0].x = (cur_velocity[0].x - omega * temp_x) * expo
	cur_velocity[0].y = (cur_velocity[0].y - omega * temp_y) * expo
	cur_velocity[0].z = (cur_velocity[0].z - omega * temp_z) * expo
	output_x = target.x + (change_x + temp_x) * expo
	output_y = target.y + (change_y + temp_y) * expo
	output_z = target.z + (change_z + temp_z) * expo
	# prevent overshooting
	var orig_minus_cur_x := original_to.x - cur.x
	var orig_minus_cur_y := original_to.y - cur.y
	var orig_minus_cur_z := original_to.z - cur.z
	var out_minus_orig_x := output_x - original_to.x
	var out_minus_orig_y := output_y - original_to.y
	var out_minus_orig_z := output_z - original_to.z
	if orig_minus_cur_x * out_minus_orig_x + orig_minus_cur_y * out_minus_orig_y + orig_minus_cur_z * out_minus_orig_z > 0:
		cur_velocity[0].x = 0.0
		cur_velocity[0].y = 0.0
		cur_velocity[0].z = 0.0
		return original_to
	return Vector3(output_x, output_y, output_z)
