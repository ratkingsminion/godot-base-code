@tool
class_name CompAudioIndexer
extends Component

@export var audio_players: Array[Dictionary] = []
@export var is_music := false

var audio_players_by_id: Dictionary = {}
var cur_music := &""
var cur_music_fade_time := 2.0

func _get(property: StringName) -> Variant:
	var i := int(str(property))
	if property.ends_with("audio_player_id"):
		if not audio_players[i].has("id"): return &""
		return audio_players[i]["id"]
	elif property.ends_with("audio_player_node_path"):
		if not audio_players[i].has("node_path"): return null
		return audio_players[i]["node_path"]
	match property:
		&"additional_audio_players": return audio_players.size()
	return null

func _set(property: StringName, value: Variant) -> bool:
	var i := int(str(property))
	if property.ends_with("audio_player_id"):
		audio_players[i]["id"] = StringName(value)
		return true
	elif property.ends_with("audio_player_node_path"):
		if value != ^"":
			var n := get_node(value)
			if n != null and not n is AudioStreamPlayer and not n is AudioStreamPlayer2D and not n is AudioStreamPlayer3D:
				printerr("Node must be AudioStreamPlayer*!")
				return false
		audio_players[i]["node_path"] = value
		return true
	match property:
		&"additional_audio_players":
			if value < 0: return false
			audio_players.resize(int(value))
			notify_property_list_changed()
			return true
	return false

func _validate_property(property: Dictionary) -> void:
	match property.name:
		"audio_players": property.usage = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_ARRAY | PROPERTY_USAGE_ALWAYS_DUPLICATE

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	
	properties.append({
		"name": "additional_audio_players", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_EDITOR
	})
	
	for i: int in audio_players.size():
		properties.append({
			"name": str(i) + ")_audio_player_id", "type": TYPE_STRING_NAME,
			"usage": PROPERTY_USAGE_EDITOR
		})
		properties.append({
			"name": str(i) + ")_audio_player_node_path", "type": TYPE_NODE_PATH, #"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_EDITOR,
			#"hint": PROPERTY_HINT_NODE_TYPE, "hint_string": "AudioStreamPlayer,AudioStreamPlayer2D,AudioStreamPlayer3D"
		})

	return properties

###

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	for c: Node in get_children():
		if c.process_mode == Node.PROCESS_MODE_INHERIT:
			c.process_mode = Node.PROCESS_MODE_PAUSABLE if process_mode == Node.PROCESS_MODE_INHERIT else process_mode
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D or c is AudioStreamPlayer3D:
			var already := false
			for ap: Dictionary in audio_players:
				if ap["node_path"] == get_path_to(c): already = true; break
			if already: continue
			audio_players.append({ "id": StringName(c.name), "node_path": get_path_to(c) })
	
	#print(get_parent().name, " has ", audio_players.size(), " audio players")
	for ap: Dictionary in audio_players:
		if ap["id"] == &"" or ap["node_path"] == ^"": continue
		var node := get_node(ap["node_path"])
		audio_players_by_id[ap.id] = {
			"id": ap.id,
			"node": node,
			"last_played": 0,
			"vol_factor": 1.0, # goes 0...1
			"std_vol_lin": db_to_linear(node.volume_db)
		}
	
	if is_music:
		process_mode = Node.PROCESS_MODE_ALWAYS
		for id: StringName in audio_players_by_id:
			var ap: Dictionary = audio_players_by_id[id]
			ap["vol_factor"] = 0.0 # start muted
			ap["node"].volume_db = linear_to_db(0.0)
	else:
		process_mode = Node.PROCESS_MODE_DISABLED

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# TODO optimize
	if is_music:
		for id: StringName in audio_players_by_id:
			var ap: Dictionary = audio_players_by_id[id]
			var target: float = 1.0 if cur_music == id else 0.0
			ap["vol_factor"] = move_toward(ap["vol_factor"], target, delta / cur_music_fade_time)
			if target == 0.0 and ap["vol_factor"] > 0.0: ap["node"].stream_paused = false
			elif target == 1.0 and ap["vol_factor"] == 0.0: ap["node"].stream_paused = true
			ap["node"].volume_db = linear_to_db(ap["std_vol_lin"] * ap["vol_factor"])
			#print(id, " ", ap["vol_music"], " ", ap["node"].volume_db, " ", ap["std_vol_lin"])

###

func set_playing(id: StringName, play: bool) -> void:
	if not audio_players_by_id.has(id): printerr("Could not find AudioPlayer ", id); return
	var ap: Dictionary = audio_players_by_id[id]
	if play: ap["node"].play()
	else: ap["node"].stop()

func stop(id: StringName) -> void:
	if not audio_players_by_id.has(id): printerr("Could not find AudioPlayer ", id); return
	var ap: Dictionary = audio_players_by_id[id]
	ap["node"].stop()

func pause(id: StringName) -> void:
	if not audio_players_by_id.has(id): printerr("Could not find AudioPlayer ", id); return
	var ap: Dictionary = audio_players_by_id[id]
	ap["node"].stream_paused = true

func unpause(id: StringName) -> void:
	if not audio_players_by_id.has(id): printerr("Could not find AudioPlayer ", id); return
	var ap: Dictionary = audio_players_by_id[id]
	ap["node"].stream_paused = false

func music_fade_in(id: StringName, fade_time := 2.0) -> void:
	if not audio_players_by_id.has(id): printerr("Could not find AudioPlayer ", id); return
	var ap: Dictionary = audio_players_by_id[id]
	if not ap["node"].playing: ap["node"].play()
	cur_music = id
	cur_music_fade_time = fade_time

func music_fade_out(fade_time := 2.0) -> void:
	cur_music = &""
	cur_music_fade_time = fade_time

func play(id: StringName, after_seconds := 0.0, must_not_playing := false) -> void:
	if not audio_players_by_id.has(id): print("!!! Could not find AudioPlayer ", id); return
	var ap: Dictionary = audio_players_by_id[id]
	if must_not_playing and ap["node"].playing: return
	if ap["last_played"] >= Time.get_ticks_msec() - after_seconds * 1000: return
	ap["node"].play()
	ap["last_played"] = Time.get_ticks_msec()

func play_at_pos_2d(id: StringName, pos: Vector2, after_seconds := 0.0, must_not_playing := false) -> void:
	if not audio_players_by_id.has(id): printerr("Could not find AudioPlayer ", id); return
	var ap: Dictionary = audio_players_by_id[id]
	if must_not_playing and ap["node"].playing: return
	if ap["last_played"] >= Time.get_ticks_msec() - after_seconds * 1000: return
	if ap["node"] is Node2D: ap["node"].global_position = pos
	else: printerr("AudioPlayer ", id, " is not a 2d node")
	ap["node"].play()
	ap["last_played"] = Time.get_ticks_msec()

func play_at_pos_3d(id: StringName, pos: Vector3, after_seconds := 0.0, must_not_playing := false) -> void:
	if not audio_players_by_id.has(id): printerr("Could not find AudioPlayer ", id); return
	var ap: Dictionary = audio_players_by_id[id]
	if must_not_playing and ap["node"].playing: return
	if ap["last_played"] >= Time.get_ticks_msec() - after_seconds * 1000: return
	if ap["node"] is Node3D: ap["node"].global_position = pos
	else: printerr("AudioPlayer ", id, " is not a 3d node")
	ap["node"].play()
	ap["last_played"] = Time.get_ticks_msec()
