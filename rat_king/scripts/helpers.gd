class_name Helpers

static var _classes: Dictionary
static var _tree: SceneTree

###

static func _static_init() -> void:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		_classes[c.class] = c.path

static func set_tree(tree: SceneTree) -> void:
	_tree = tree

### screenshots

static func take_screenshot(path := "./screenshot", as_jpg := true) -> void:
	var dir := path
	if not dir.ends_with("/") and not dir.ends_with("\\"):
		var idx_s := dir.rfind("/")
		var idx_b := dir.rfind("\\")
		dir = dir.substr(0, idx_s if idx_s > idx_b else idx_b)
	var dir_access := DirAccess.open("user://") if path.begins_with("user://") else DirAccess.open("res://")
	if not dir_access.dir_exists(dir): dir_access.make_dir_recursive(dir)
	var image := _tree.root.get_viewport().get_texture().get_image()
	var timestamp := Time.get_datetime_string_from_system(false, true).replace(" ", "_").replace(":", "").replace("-", "")
	path = path + "_" + timestamp + (".jpg" if as_jpg else ".png")
	var res := image.save_jpg(path) if as_jpg else image.save_png(path)
	if res == OK: print("screenshot saved: ", path)

### find nodes and classes

static func get_all_children(node: Node, include_self := false, include_internal := false) -> Array[Node]:
	var to_check: Array[Node] = [ node ]
	var result: Array[Node] = []
	if include_self:
		result.append(node)
	while to_check.size() > 0:
		var c := (to_check.pop_back() as Node).get_children(include_internal) # pop_front is slow unfortunately
		result.append_array(c)
		to_check.append_array(c)
	return result

#

## class does not respect class_name! use find_type for that
static func find_class_in_children(node: Node, name_of_class: StringName, include_self := true, include_internal := false) -> Node:
	if node == null: return null
	if include_self and node.is_class(name_of_class): return node
	for child: Node in node.get_children(include_internal):
		if child.is_class(name_of_class): return child
	return null

## class does not respect class_name! use find_type for that
static func find_all_class_in_children(node: Node, name_of_class: StringName, include_self := true, include_internal := false) -> Array[Node]:
	if node == null: return []
	var result: Array[Node] = []
	if include_self and node.is_class(name_of_class): result.push_back(node)
	for child: Node in node.get_children(include_internal):
		if child.is_class(name_of_class): result.push_back(child)
	return result

## class does not respect class_name! use find_type for that
static func find_class_in_all_children(node: Node, name_of_class: StringName, include_self := true, include_internal := false) -> Node:
	if node == null: return null
	if include_self and node.is_class(name_of_class): return node
	for child: Node in Helpers.get_all_children(node, false, include_internal):
		if child.is_class(name_of_class): return child
	return null

## class does not respect class_name! use find_type for that
static func find_all_class_in_all_children(node: Node, name_of_class: StringName, include_self := true, include_internal := false) -> Array[Node]:
	if node == null: return []
	var result: Array[Node] = []
	for child: Node in Helpers.get_all_children(node, include_self, include_internal):
		if child.is_class(name_of_class): result.push_back(child)
	return result

## class does not respect class_name! use find_type for that
static func find_class_in_all_parents(node: Node, name_of_class: StringName, include_self := true) -> Node:
	if node == null: return null
	if include_self and node.is_class(name_of_class): return node
	node = node.get_parent()
	while node != null:
		if node.is_class(name_of_class): return node
		node = node.get_parent()
	return null

#

## this does not recognize a custom type (class_name) inheriting from another custom type!
static func find_type_in_children(node: Node, name_of_type: StringName, include_self := true, include_internal := false) -> Node:
	if node == null: return null
	if include_self and node.is_class(name_of_type): return node
	if include_self and node.get_script() != null and _classes[name_of_type] == node.get_script().get_path():
		return node
	for child: Node in node.get_children(include_internal):
		if child.is_class(name_of_type): return child
		if child.get_script() != null and _classes[name_of_type] == child.get_script().get_path():
			return child
	return null

## this does not recognize a custom type (class_name) inheriting from another custom type!
static func find_all_type_in_children(node: Node, name_of_type: StringName, include_self := true, include_internal := false) -> Array[Node]:
	if node == null: return []
	var result: Array[Node] = []
	if include_self and node.is_class(name_of_type): result.push_back(node)
	if include_self and node.get_script() != null and _classes[name_of_type] == node.get_script().get_path():
		result.push_back(node)
	for child: Node in node.get_children(include_internal):
		if child.is_class(name_of_type): result.push_back(child)
		if child.get_script() != null and _classes[name_of_type] == child.get_script().get_path():
			result.push_back(child)
	return result

## this does not recognize a custom type (class_name) inheriting from another custom type!
static func find_type_in_all_children(node: Node, name_of_type: StringName, include_self := true, include_internal := false) -> Node:
	if node == null: return null
	if include_self and node.is_class(name_of_type): return node
	if include_self and node.get_script() != null and _classes[name_of_type] == node.get_script().get_path():
		return node
	for child: Node in Helpers.get_all_children(node, false, include_internal):
		if child.is_class(name_of_type): return child
		var script = child.get_script()
		if script != null and _classes[name_of_type] == script.get_path(): return child
	return null

## this does not recognize a custom type (class_name) inheriting from another custom type!
static func find_all_type_in_all_children(node: Node, name_of_type: StringName, include_self := true, include_internal := false) -> Array[Node]:
	if node == null: return []
	var result: Array[Node] = []
	for child: Node in Helpers.get_all_children(node, include_self, include_internal):
		if child.is_class(name_of_type): result.push_back(child)
		var script = child.get_script()
		if script != null and _classes[name_of_type] == script.get_path(): result.push_back(child)
	return result

## this does not recognize a custom type (class_name) inheriting from another custom type!
static func find_type_in_all_parents(node: Node, name_of_type: StringName, include_self := true) -> Node:
	if node == null: return null
	if include_self and node.is_class(name_of_type): return node
	if include_self and node.get_script() != null and _classes[name_of_type] == node.get_script().get_path():
		return node
	node = node.get_parent()
	while node != null:
		if node.is_class(name_of_type): return node
		if node.get_script() != null and _classes[name_of_type] == node.get_script().get_path():
			return node
		node = node.get_parent()
	return null
	
### gui

static func is_text_edit_focused(node: Node) -> bool:
	if node == null: return false
	var focused := node.get_viewport().gui_get_focus_owner()
	if focused == null: return false
	if focused is LineEdit or focused is TextEdit: return true
	return false

static func scroll_container_to_end(container: Control, forced := false) -> void:
	if container == null: return
	if container.is_inside_tree():
		await container.get_tree().process_frame
	var count := container.get_child_count()
	if not forced and container.get_meta("scroll_last_count", 0) == count:
		return
	var _scroller: ScrollContainer = Helpers.find_class_in_all_parents(container, "ScrollContainer")
	_scroller.scroll_vertical = int(container.size.y)
	container.set_meta("scroll_last_count", count)
	
### waiting and timing

## coroutine
static func tree_do_next_frame(on_complete: Callable) -> void:
	await _tree.process_frame
	on_complete.call()

## coroutine
static func do_next_frame(node: Node, on_complete: Callable) -> void:
	await node.get_tree().process_frame
	on_complete.call()

## coroutine
static func tree_timout(seconds: float) -> void:
	if seconds <= 0.0: return
	if _tree == null: printerr("Trying to timeout without tree"); return
	await _tree.create_timer(seconds).timeout

## coroutine
static func timeout(node: Node, seconds: float) -> void:
	if seconds <= 0.0: return
	if node == null: printerr("Trying to timeout without node"); return
	var timer = Timer.new()
	timer.one_shot = true
	node.add_child(timer)
	timer.start(seconds)
	await timer.timeout

static func cur_time(multiplier := 1.0) -> float:
	return Time.get_ticks_msec() * 0.001 * multiplier

### signals

static func clear_signal_connections(s: Signal) -> void:
	for sc: Dictionary in s.get_connections():
		s.disconnect(sc["callable"])
