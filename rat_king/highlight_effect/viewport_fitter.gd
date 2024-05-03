class_name ViewportFitter
extends SubViewport

###

func _ready() -> void:
	_match_root_viewport()
	get_tree().get_root().size_changed.connect(_match_root_viewport)

###

func _match_root_viewport() -> void:
	size = get_tree().get_root().size 
