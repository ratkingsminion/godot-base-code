class_name FluidFSM
extends Node

## A callable-based FSM node, created on-the-fly via code.
## Create an FSM like this:
##
## enum MyState { IDLE, WALK, DEAD }
## var fsm := FluidFSM.create(<parent_node>)
## # Add a state:
## var state_idle = fsm.add_state(MyState.IDLE)
## state_idle.can_change_to(func(next: MyState) -> bool: return next != MyState.DEAD)
## state_idle.on_leave(_on_leave_idle_state)
## # ...or do it via fluid method currying:
## fsm.add_state(MyState.WALK).on_enter(func(prev: MyState) -> void:
##	...
## ).on_process(func(delta: float) -> void:
##	...
## )
## fsm.set_state(MyState.IDLE)
##
## Possible calls 
## can_change_to(func(next: MyState) -> bool)
## can_change_from(func(prev: MyState) -> bool)
## on_enter(func(prev: MyState) -> void)
## on_leave(func(next: MyState) -> void)
## on_process(func(delta: float) -> void) # only if the FSM object is in scene tree
## on_physics_process(func(delta: float) -> void) # only if the FSM object is in scene tree
## on_input(func(event: InputEvent) -> void) # only if the FSM object is in scene tree
##
## If you want you can also use strings (for example) instead of an enum as state identifiers.

class FluidState:
	var _id
	var _can_change_to := Callable()
	var _can_change_from := Callable()
	var _on_enter := Callable()
	var _on_leave := Callable()
	var _on_process := Callable()
	var _on_physics_process := Callable()
	var _on_input := Callable()
	
	func _init(id) -> void:
		_id = id
	
	## callable takes "next" as argument and returns bool
	func can_change_to(callable: Callable) -> FluidState:
		_can_change_to = callable
		return self
	
	## callable takes "prev" as argument and returns bool
	func can_change_from(callable: Callable) -> FluidState:
		_can_change_from = callable
		return self
	
	## callable takes "prev" as argument
	func on_enter(callable: Callable) -> FluidState:
		_on_enter = callable
		return self
	
	## callable takes "next" as argument
	func on_leave(callable: Callable) -> FluidState:
		_on_leave = callable
		return self
	
	## callable takes "delta: float" as argument
	func on_process(callable: Callable) -> FluidState:
		_on_process = callable
		return 
	
	## callable takes "delta: float" as argument
	func on_physics_process(callable: Callable) -> FluidState:
		_on_physics_process = callable
		return 
	
	## callable takes "event: InputEvent" as argument
	func on_input(callable: Callable) -> FluidState:
		_on_input = callable
		return 

var _states: Dictionary # Variant -> FluidState
var _state: FluidState = null
var _can_process := true

signal state_changed(from: int, to: int)

###

static func create(parent: Node = null) -> FluidFSM:
	var fsm := FluidFSM.new()
	if parent != null: parent.call_deferred("add_child", fsm)
	fsm.set_process_input(false)
	fsm.set_process(false)
	fsm.set_physics_process(false)
	return fsm

###

func override_process(enabled: bool) -> void:
	_can_process = enabled
	set_process_input(enabled and _state and _state._on_input)
	set_process(enabled and _state and _state._on_process)
	set_physics_process(enabled and _state and _state._on_physics_process)

func add_state(state_id) -> FluidState:
	if _states.has(state_id): return _states[state_id]
	var state := FluidState.new(state_id)
	_states[state_id] = state
	return state

func set_state(state_id, force := false) -> bool:
	if _state and _state._id == state_id: return false
	if state_id != null and not _states.has(state_id): return false
	
	var prev_id = _state._id if _state else null
	var next: FluidState = (_states[state_id] as FluidState) if state_id != null else null
	
	if not force:
		if _state and _state._can_change_to and not _state._can_change_to.call(state_id):
			return false
		if next and next._can_change_from and not next._can_change_from.call(prev_id):
			return false
	
	if _state and _state._on_leave:
		_state._on_leave.call(state_id)

	_state = next
	state_changed.emit(prev_id, state_id)

	if _state and _state._on_enter:
		_state._on_enter.call(prev_id)
	
	override_process(_can_process)
	
	return true

func set_no_state(force := false) -> bool:
	return set_state(null, force)

func get_state():
	return _state._id if _state else null

###

func _ready() -> void:
	override_process(_can_process)

func _input(event: InputEvent) -> void:
	_state._on_input.call(event)

func _process(delta: float) -> void:
	_state._on_process.call(delta)

func _physics_process(delta: float) -> void:
	_state._on_physics_process.call(delta)
