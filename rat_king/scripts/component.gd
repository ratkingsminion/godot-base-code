class_name Component
extends Node

@onready var parent: Node = get_parent()
@onready var parent_2d := get_parent() as Node2D # is null if parent is not a Node2D!
@onready var parent_3d := get_parent() as Node3D # is null if parent is not a Node3D!
@onready var node_2d := $"." as Node2D # is null if component is not a Node2D!
@onready var node_3d := $"." as Node3D # is null if component is not a Node3D!

var is_active := true

###

# use from components
func find_type_in_siblings(component_name: StringName) -> Node:
	return Helpers.find_type_in_children(get_parent(), component_name)

func deactivate() -> void:
	if not is_active: return
	is_active = false
	parent.remove_child.call_deferred(self)

func activate() -> void:
	if is_active: return
	is_active = true
	parent.add_child.call_deferred(self)

func set_active(active: bool) -> void:
	if active: activate()
	else: deactivate()
