class_name Tweens
extends Node

static var _tree: SceneTree = Engine.get_main_loop()

###

static func set_tree(tree: SceneTree) -> void:
	_tree = tree

###

static func timer(node: Node, duration: float, on_complete: Callable) -> Tween:
	if node == null or duration < 0.0: return null
	var t := node.create_tween()
	t.tween_interval(duration)
	t.tween_callback(on_complete)
	return t

static func do_01(node: Node, duration: float, on_update: Callable, trans := Tween.TRANS_LINEAR, ease := Tween.EASE_IN_OUT) -> Tween:
	if node == null or duration < 0.0: return null
	var t := node.create_tween().set_trans(trans).set_ease(ease)
	t.tween_method(on_update, 0.0, 1.0, duration)
	return t

static func do(node: Node, start, end, duration: float, on_update: Callable, trans := Tween.TRANS_LINEAR, ease := Tween.EASE_IN_OUT) -> Tween:
	if node == null or duration < 0.0: return null
	var t := node.create_tween().set_trans(trans).set_ease(ease)
	t.tween_method(func(f: float) -> void: on_update.call(lerp(start, end, f)), 0.0, 1.0, duration)
	return t

static func do_01_curve(node: Node, duration: float, curve: Curve, on_update: Callable, trans := Tween.TRANS_LINEAR, ease := Tween.EASE_IN_OUT) -> Tween:
	if node == null or duration < 0.0 or curve == null: return null
	var t := node.create_tween().set_trans(trans).set_ease(ease)
	t.tween_method(func(f: float) -> void: on_update.call(curve.sample(f)), 0.0, 1.0, duration)
	return t

static func do_curve(node: Node, start, end, duration: float, curve: Curve, on_update: Callable, trans := Tween.TRANS_LINEAR, ease := Tween.EASE_IN_OUT) -> Tween:
	if node == null or duration < 0.0 or curve == null: return null
	var t := node.create_tween().set_trans(trans).set_ease(ease)
	t.tween_method(func(f: float) -> void: on_update.call(lerp(start, end, curve.sample(f))), 0.0, 1.0, duration)
	return t

###

static func tree_timer(duration: float, on_complete: Callable) -> Tween:
	if _tree == null: printerr("Trying to tween without tree"); return null
	if duration < 0.0: return null
	var t := _tree.create_tween()
	t.tween_interval(duration)
	t.tween_callback(on_complete)
	return t

static func tree_do_01(duration: float, on_update: Callable) -> Tween:
	if _tree == null: printerr("Trying to tween without tree"); return null
	if duration < 0.0: return null
	var t := _tree.create_tween()
	t.tween_method(on_update, 0.0, 1.0, duration)
	return t

static func tree_do(start, end, duration: float, on_update: Callable) -> Tween:
	if _tree == null: printerr("Trying to tween without tree"); return null
	if duration < 0.0: return null
	var t := _tree.create_tween()
	t.tween_method(func(f: float) -> void: on_update.call(lerp(start, end, f)), 0.0, 1.0, duration)
	return t

static func tree_do_01_curve(duration: float, curve: Curve, on_update: Callable) -> Tween:
	if _tree == null: printerr("Trying to tween without tree"); return null
	if duration < 0.0 or curve == null: return null
	var t := _tree.create_tween()
	t.tween_method(func(f: float) -> void: on_update.call(curve.sample(f)), 0.0, 1.0, duration)
	return t

static func tree_do_curve(start, end, duration: float, curve: Curve, on_update: Callable) -> Tween:
	if _tree == null: printerr("Trying to tween without tree"); return null
	if duration < 0.0 or curve == null: return null
	var t := _tree.create_tween()
	t.tween_method(func(f: float) -> void: on_update.call(lerp(start, end, curve.sample(f))), 0.0, 1.0, duration)
	return t

###

# easings from: https://github.com/ai/easings.net/blob/master/src/easings/easingsFunctions.ts

const _c1 := 1.70158
const _c2 := _c1 * 1.525
const _c3 := _c1 + 1
const _c4 := (2.0 * PI) / 3.0
const _c5 := (2.0 * PI) / 4.5

static func _bounce_out(t: float) -> float:
	var n1 := 7.5625
	var d1 := 2.75
	if t < 1.0 / d1:
		return n1 * t * t
	elif t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elif t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	t -= 2.625 / d1
	return n1 * t * t + 0.984375

static func in_quad(t: float) -> float:
	return t * t

static func out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

static func in_out_quad(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5

static func in_cubic(t: float) -> float:
	return t * t * t

static func out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

static func in_out_cubic(t: float) -> float:
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5

static func in_quart(t: float) -> float:
	var tt := t * t
	return tt * tt

static func out_quart(t: float) -> float:
	return 1.0 - pow(1 - t, 4.0)

static func in_out_quart(t: float) -> float:
	var tt := t * t
	return 8.0 * tt * tt if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 4.0) * 0.5

static func in_quint(t: float) -> float:
	var tt := t * t
	return tt * tt * t

static func out_quint(t: float) -> float:
	return 1.0 - pow(1.0 - t, 5.0)

static func in_out_quint(t: float) -> float:
	var tt := t * t
	return 16.0 * tt * tt * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 5.0) * 0.5

static func in_sin(t: float) -> float:
	return 1.0 - cos((t * PI) * 0.5)

static func out_sin(t: float) -> float:
	return sin((t * PI) * 0.5)

static func in_out_sin(t: float) -> float:
	return -(cos(PI * t) - 1.0) * 0.5

static func in_expo(t: float) -> float:
	return 0.0 if t == 0.0 else pow(2.0, 10.0 * t - 10.0)

static func out_expo(t: float) -> float:
	return 1.0 if t == 1.0 else 1.0 - pow(2.0, -10.0 * t)

static func in_out_expo(t: float) -> float:
	return 0.0 if t == 0.0 \
		else 1.0 if t == 1.0 \
		else pow(2.0, 20.0 * t - 10.0) * 0.5 if t < 0.5 \
		else (2.0 - pow(2.0, -20.0 * t + 10.0)) * 0.5

static func in_circ(t: float) -> float:
	return 1.0 - sqrt(1.0 - pow(t, 2.0))

static func out_circ(t: float) -> float:
	return sqrt(1.0 - pow(t - 1.0, 2.0))

static func in_out_circ(t: float) -> float:
	return (1.0 - sqrt(1 - pow(2.0 * t, 2.0))) * 0.5 if t < 0.5 \
		else (sqrt(1.0 - pow(-2.0 * t + 2.0, 2.0)) + 1.0) * 0.5

static func in_back(t: float) -> float:
	var tt := t * t
	return _c3 * tt * t - _c1 * tt

static func out_back(t: float) -> float:
	return 1.0 + _c3 * pow(t - 1.0, 3.0) + _c1 * pow(t - 1.0, 2.0)

static func in_out_back(t: float) -> float:
	return (pow(2.0 * t, 2.0) * ((_c2 + 1.0) * 2.0 * t - _c2)) * 0.5 if t < 0.5 \
		else (pow(2.0 * t - 2.0, 2.0) * ((_c2 + 1.0) * (t * 2.0 - 2.0) + _c2) + 2.0) * 0.5

static func in_elastic(t: float) -> float:
	return 0.0 if t == 0.0 \
		else 1.0 if t == 1.0 \
		else -pow(2.0, 10.0 * t - 10.0) * sin((t * 10.0 - 10.75) * _c4)

static func out_elastic(t: float) -> float:
	return 0.0 if t == 0.0 \
		else 1.0 if t == 1.0 \
		else pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * _c4) + 1.0

static func in_out_elastic(t: float) -> float:
	return 0.0 if t == 0.0 \
		else 1.0 if t == 1.0 \
		else -(pow(2.0, 20.0 * t - 10.0) * sin((20.0 * t - 11.125) * _c5)) * 0.5 if t < 0.5 \
		else (pow(2.0, -20.0 * t + 10.0) * sin((20.0 * t - 11.125) * _c5)) * 0.5 + 1.0

static func in_bounce(t: float) -> float:
	return 1.0 - _bounce_out(1.0 - t)

static func out_bounce(t: float) -> float:
	return _bounce_out(t)

static func in_out_bounce(t: float) -> float:
	return (1.0 - _bounce_out(1.0 - 2.0 * t)) * 0.5 if t < 0.5 \
		else (1.0 + _bounce_out(2.0 * t - 1.0)) * 0.5

static func out_spring(t: float) -> float:
	t /= 1.0
	var s := 1.0 - t
	t = (sin(t * PI * (0.2 + 2.5 * t * t * t)) * pow(s, 2.2) + t) * (1.0 + (1.2 * s))
	return 1.0 * t + 0.0

static func in_spring(t: float) -> float:
	return 1.0 - out_spring(1.0 - t) + 0.0

static func out_in_spring(t: float) -> float:
	if t < 1.0 * 0.5: return out_spring(t * 2.0)
	return in_spring(t * 2.0 - 1.0)

static func in_out_spring(t: float) -> float:
	if t < 1.0 * 0.5: return in_spring(t * 2.0)
	return out_spring(t * 2.0 - 1.0)
