class_name SimpleFSM
extends Node

## A method-based FSM node, created on-the-fly via code.
## Create an FSM like this:
##
## enum MyState { IDLE, WALK, DEAD }
## var fsm := SimpleFSM.create(MyState, <target_object>)
## fsm.set_state(MyState.IDLE)
##
## Possible methods in <target_object>:
##
## func _can_change_state_<state_name>_to(next: MyState) -> bool
## func _can_change_state_<state_name>_from(prev: MyState) -> bool
## func _enter_state_<state_name>(prev: MyState) -> void
## func _leave_state_<state_name>(next: MyState) -> void
## func _process_state_<state_name>(delta: float) -> void # only if <target_object> is a node
## func _physics_process_state_<state_name>(delta: float) -> void # only if <target_object> is a node
## func _input_state_<state_name>(event: InputEvent) -> void # only if <target_object> is a node
##
## Usually <state_name> is the lower-case version of the MyState members, but
## you can change this via the third parameter in SimpleFSM.create()

static var _empty: Dictionary = { &"i": Callable(), &"p": Callable(), &"pp": Callable() }

var _states: Dictionary = { } # int -> Dictionary[StringName -> Callable]
var _state := -1
var _process_callable := Callable()
var _physics_process_callable := Callable()
var _input_callable := Callable()
var _can_process := true

signal state_changed(from: int, to: int)

###

static func create(states: Dictionary, target: Object = null, force_lower := true) -> SimpleFSM:
	var fsm := SimpleFSM.new()
	for s in states:
		var str_name := StringName(str(s).to_lower() if force_lower else str(s))
		var callables := { }
		if target.has_method("_can_change_state_" + str_name + "_to"):
			callables[&"ct"] = target["_can_change_state_" + str_name + "_to"]
		if target.has_method("_can_change_state_" + str_name + "_from"):
			callables[&"cf"] = target["_can_change_state_" + str_name + "_from"]
		if target.has_method("_enter_state_" + str_name):
			callables[&"e"] = target["_enter_state_" + str_name]
		if target.has_method("_leave_state_" + str_name):
			callables[&"l"] = target["_leave_state_" + str_name]
		callables[&"p"] = target["_process_state_" + str_name] if target.has_method("_process_state_" + str_name) else Callable()
		callables[&"pp"] = target["_physics_process_state_" + str_name] if target.has_method("_physics_process_state_" + str_name) else Callable()
		callables[&"i"] = target["_input_state_" + str_name] if target.has_method("_input_state_" + str_name) else Callable()
		fsm._states[states[s]] = callables
	
	if target != null and target is Node:
		(target as Node).call_deferred("add_child", fsm)
	
	return fsm

###

func override_process(enabled: bool) -> void:
	_can_process = enabled
	set_process(enabled and _process_callable)
	set_physics_process(enabled and _physics_process_callable)
	set_process_input(enabled and _input_callable)

func set_state(state: int, force := false) -> bool:
	if _state == state:
		return false
		
	var prev := (_states[_state] as Dictionary) if _states.has(_state) else _empty
	var next := (_states[state] as Dictionary) if _states.has(state) else _empty
	
	if not force:
		if prev.has(&"ct") and not (prev[&"ct"] as Callable).call(state):
			return false
		if next.has(&"cf") and not (next[&"cf"] as Callable).call(_state):
			return false
	
	if prev.has(&"l"):
		(prev[&"l"] as Callable).call(state)
	
	var prev_state := _state
	_state = state
	state_changed.emit(prev_state, _state)
	
	if next.has(&"e"):
		(next[&"e"] as Callable).call(prev_state)

	_process_callable = next[&"p"] as Callable
	_physics_process_callable = next[&"pp"] as Callable
	_input_callable = next[&"i"] as Callable
	
	override_process(_can_process)
	
	return true

func set_no_state(force := false) -> bool:
	return set_state(-1, force)

func get_state() -> int:
	return _state

###

func _ready() -> void:
	override_process(_can_process)

func _process(delta: float) -> void:
	_process_callable.call(delta)

func _physics_process(delta: float) -> void:
	if _physics_process_callable:
		_physics_process_callable.call(delta)

func _input(event: InputEvent) -> void:
	if _input_callable:
		_input_callable.call(event)
