class_name Tweens
extends Node

static var _tree: SceneTree

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
