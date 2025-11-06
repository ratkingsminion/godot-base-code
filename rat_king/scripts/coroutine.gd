class_name Coroutine
extends Node

static var _index := 0

var idx: int
var paused: bool
var routine: Callable

###

## routine must return bool
## -> true: routine stops, false: routine continues to get called every frame
static func create(routine: Callable, parent: Node = null) -> Coroutine:
	var node := Coroutine.new()
	node.idx = _index
	_index += 1
	node.routine = routine
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	if parent: parent.add_child(node)
	else: (Engine.get_main_loop() as SceneTree).root.add_child(node)
	return node

###

func _process(delta: float) -> void:
	if paused: return
	if not routine or routine.call(): kill()

func pause() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

func resume() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func kill() -> void:
	queue_free()
